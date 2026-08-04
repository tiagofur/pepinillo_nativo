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

    public AuthViewModel(IBackendApiClient backend, ISyncService sync, ISettingsService settings)
    {
        _backend = backend;
        _sync = sync;
        _settings = settings;
    }

    public async Task InitializeAsync()
    {
        try
        {
            await _backend.InitializeAsync();
            IsAuthenticated = _backend.IsAuthenticated;
            await RefreshLastSyncDisplayAsync();
            UpdateAccountModeLabel();
            StatusMessage = IsAuthenticated
                ? "Signed in (token restored). Cloud sync needs Everywhere."
                : "Not signed in — offline local mode. Cloud sync needs Everywhere. Local data always works.";
            LastError = _backend.LastError ?? string.Empty;
        }
        catch (Exception ex)
        {
            IsAuthenticated = false;
            UpdateAccountModeLabel();
            StatusMessage = $"Auth init failed: {ex.Message}";
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
                ? "Signed in successfully."
                : (_backend.LastError ?? "Login failed (check credentials or network).");
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
            StatusMessage = $"Login error: {ex.Message}";
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
                    ?? "Registration failed (network or email already used).";
            }
            else if (IsAuthenticated)
            {
                StatusMessage = "Account created — signed in.";
                Password = string.Empty;
                await SyncNowAsync();
            }
            else
            {
                StatusMessage = "Account created. Sign in to continue.";
            }
        }
        catch (Exception ex)
        {
            StatusMessage = $"Registration error: {ex.Message}";
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
            StatusMessage = "Signed out. Local data always works offline.";
            SyncStatus = string.Empty;
            LastError = string.Empty;
        }
        catch (Exception ex)
        {
            StatusMessage = $"Logout error: {ex.Message}";
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
            SyncStatus = $"Sync failed: {ex.Message}";
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
            StatusMessage = "Enter a valid email address.";
            return false;
        }

        if (requirePassword && string.IsNullOrWhiteSpace(Password))
        {
            StatusMessage = "Email and password are required.";
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
                : "Never";
        }
        catch
        {
            LastSyncDisplay = "Never";
        }
    }

    private void UpdateAccountModeLabel()
    {
        AccountModeLabel = IsAuthenticated
            ? "Signed in — cloud sync when Everywhere is active"
            : "Local only — not signed in";
    }
}
