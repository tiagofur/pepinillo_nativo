using System;
using System.Threading.Tasks;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using Pepinillo.Core.Services;

namespace Pepinillo.Core.ViewModels;

public partial class AuthViewModel : ObservableObject
{
    private readonly IBackendApiClient _backend;
    private readonly ISyncService _sync;
    private readonly ISettingsService _settings;
    private readonly ILocalizationService? _localizer;

    [ObservableProperty]
    private string _email = string.Empty;

    [ObservableProperty]
    private string _password = string.Empty;

    [ObservableProperty]
    private string _displayName = string.Empty;

    [ObservableProperty]
    private string _statusMessage = string.Empty;

    [ObservableProperty]
    [NotifyPropertyChangedFor(nameof(CanInteract))]
    private bool _isBusy;

    /// <summary>False while an auth/sync command is running (disables form controls).</summary>
    public bool CanInteract => !IsBusy;

    [ObservableProperty]
    private bool _isAuthenticated;

    [ObservableProperty]
    private string _syncStatus = string.Empty;

    [ObservableProperty]
    private string _lastSyncDisplay = "Never";

    [ObservableProperty]
    private string _lastError = string.Empty;

    [ObservableProperty]
    private string _accountModeLabel = "Local only — not signed in";

    [ObservableProperty]
    private string _titleLabel = "Account";

    [ObservableProperty]
    private string _subtitleLabel =
        "Sign in to sync sessions with Everywhere. Local focus data always works offline — free/local users stay local-first.";

    [ObservableProperty]
    private string _emailLabel = "Email";

    [ObservableProperty]
    private string _passwordLabel = "Password";

    [ObservableProperty]
    private string _displayNameLabel = "Display name (register)";

    [ObservableProperty]
    private string _loginLabel = "Sign in";

    [ObservableProperty]
    private string _registerLabel = "Create account";

    [ObservableProperty]
    private string _logoutLabel = "Sign out";

    [ObservableProperty]
    private string _syncNowLabel = "Sync now";

    [ObservableProperty]
    private string _lastSyncPrefix = "Last sync: ";

    [ObservableProperty]
    private string _cloudSyncHint =
        "Cloud sync needs Everywhere. Local data always works.";

    public AuthViewModel(
        IBackendApiClient backend,
        ISyncService sync,
        ISettingsService settings,
        ILocalizationService? localizer = null)
    {
        _backend = backend;
        _sync = sync;
        _settings = settings;
        _localizer = localizer;
    }

    public async Task InitializeAsync()
    {
        await ApplyLanguageAsync();
        try
        {
            await _backend.InitializeAsync();
            IsAuthenticated = _backend.IsAuthenticated;
            await RefreshLastSyncDisplayAsync();
            UpdateAccountModeLabel();
            StatusMessage = IsAuthenticated
                ? T("Account.SignedInTokenRestored",
                    "Signed in (token restored). Cloud sync needs Everywhere.")
                : T("Account.NotSignedInOffline",
                    "Not signed in — offline local mode. Cloud sync needs Everywhere. Local data always works.");
            LastError = _backend.LastError ?? string.Empty;
        }
        catch (Exception ex)
        {
            IsAuthenticated = false;
            UpdateAccountModeLabel();
            StatusMessage = string.Format(
                T("Account.AuthInitFailed", "Auth init failed: {0}"),
                ex.Message);
            LastError = ex.Message;
        }
    }

    [RelayCommand]
    private async Task LoginAsync()
    {
        if (!ValidateCredentials(requirePassword: true))
            return;

        IsBusy = true;
        try
        {
            var ok = await _backend.LoginAsync(Email.Trim(), Password);
            IsAuthenticated = ok;
            LastError = _backend.LastError ?? string.Empty;
            UpdateAccountModeLabel();
            StatusMessage = ok
                ? T("Account.SignedInSuccess", "Signed in successfully.")
                : (_backend.LastError
                    ?? T("Account.LoginFailed",
                        "Login failed (check credentials or network)."));
            if (ok)
            {
                Password = string.Empty;
                await SyncNowAsync();
            }
        }
        catch (Exception ex)
        {
            IsAuthenticated = false;
            UpdateAccountModeLabel();
            StatusMessage = string.Format(
                T("Account.LoginError", "Login error: {0}"),
                ex.Message);
            LastError = ex.Message;
        }
        finally
        {
            IsBusy = false;
        }
    }

    [RelayCommand]
    private async Task RegisterAsync()
    {
        if (!ValidateCredentials(requirePassword: true))
            return;

        IsBusy = true;
        try
        {
            var name = string.IsNullOrWhiteSpace(DisplayName) ? Email.Split('@')[0] : DisplayName.Trim();
            var ok = await _backend.RegisterAsync(Email.Trim(), Password, name);
            IsAuthenticated = ok && _backend.IsAuthenticated;
            LastError = _backend.LastError ?? string.Empty;
            UpdateAccountModeLabel();

            if (!ok)
            {
                StatusMessage = _backend.LastError
                    ?? T("Account.RegistrationFailed",
                        "Registration failed (network or email already used).");
            }
            else if (IsAuthenticated)
            {
                StatusMessage = T("Account.AccountCreated", "Account created — signed in.");
                Password = string.Empty;
                await SyncNowAsync();
            }
            else
            {
                StatusMessage = T("Account.AccountCreatedSignIn",
                    "Account created. Sign in to continue.");
            }
        }
        catch (Exception ex)
        {
            StatusMessage = string.Format(
                T("Account.RegistrationError", "Registration error: {0}"),
                ex.Message);
            LastError = ex.Message;
        }
        finally
        {
            IsBusy = false;
        }
    }

    [RelayCommand]
    private async Task LogoutAsync()
    {
        IsBusy = true;
        try
        {
            await _backend.LogoutAsync();
            IsAuthenticated = false;
            UpdateAccountModeLabel();
            StatusMessage = T("Account.SignedOut",
                "Signed out. Local data always works offline.");
            SyncStatus = string.Empty;
            LastError = string.Empty;
        }
        catch (Exception ex)
        {
            StatusMessage = string.Format(
                T("Account.LogoutError", "Logout error: {0}"),
                ex.Message);
            LastError = ex.Message;
        }
        finally
        {
            IsBusy = false;
        }
    }

    [RelayCommand]
    private async Task SyncNowAsync()
    {
        IsBusy = true;
        try
        {
            var result = await _sync.SyncNowAsync();
            SyncStatus = result.Message;
            if (!string.IsNullOrEmpty(result.Message))
                StatusMessage = result.Message;
            LastError = result.Success
                ? string.Empty
                : (_backend.LastError ?? result.Message);
            await RefreshLastSyncDisplayAsync();
            UpdateAccountModeLabel();
        }
        catch (Exception ex)
        {
            SyncStatus = string.Format(
                T("Account.SyncFailed", "Sync failed: {0}"),
                ex.Message);
            StatusMessage = SyncStatus;
            LastError = ex.Message;
        }
        finally
        {
            IsBusy = false;
        }
    }

    private bool ValidateCredentials(bool requirePassword)
    {
        if (string.IsNullOrWhiteSpace(Email) || !Email.Contains('@', StringComparison.Ordinal))
        {
            StatusMessage = T("Account.ValidEmail", "Enter a valid email address.");
            return false;
        }

        if (requirePassword && string.IsNullOrWhiteSpace(Password))
        {
            StatusMessage = T("Account.EmailPasswordRequired",
                "Email and password are required.");
            return false;
        }

        return true;
    }

    private async Task RefreshLastSyncDisplayAsync()
    {
        try
        {
            var settings = await _settings.GetSettingsAsync();
            LastSyncDisplay = settings.LastSyncAtUtc.HasValue
                ? settings.LastSyncAtUtc.Value.ToLocalTime().ToString("g")
                : T("Common.Never", "Never");
        }
        catch
        {
            LastSyncDisplay = T("Common.Never", "Never");
        }
    }

    private void UpdateAccountModeLabel()
    {
        AccountModeLabel = IsAuthenticated
            ? T("Account.SignedInMode",
                "Signed in — cloud sync when Everywhere is active")
            : T("Account.LocalOnly", "Local only — not signed in");
    }

    private async Task ApplyLanguageAsync()
    {
        if (_localizer == null) return;

        try
        {
            var settings = await _settings.GetSettingsAsync();
            _localizer.SetLanguage(settings.PreferredLanguage);
        }
        catch
        {
            // keep current
        }

        TitleLabel = T("Account.Title", "Account");
        SubtitleLabel = T("Account.Subtitle", SubtitleLabel);
        EmailLabel = T("Account.Email", "Email");
        PasswordLabel = T("Account.Password", "Password");
        DisplayNameLabel = T("Account.DisplayName", "Display name (register)");
        LoginLabel = T("Account.Login", "Sign in");
        RegisterLabel = T("Account.Register", "Create account");
        LogoutLabel = T("Account.Logout", "Sign out");
        SyncNowLabel = T("Account.SyncNow", "Sync now");
        LastSyncPrefix = T("Account.LastSync", "Last sync: ");
        CloudSyncHint = T("Account.CloudSyncNeedsEverywhere",
            "Cloud sync needs Everywhere. Local data always works.");
        UpdateAccountModeLabel();
    }

    private string T(string key, string fallback) =>
        _localizer?.GetString(key) ?? fallback;
}
