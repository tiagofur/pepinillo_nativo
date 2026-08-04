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

    [ObservableProperty]
    private string _email = string.Empty;

    [ObservableProperty]
    private string _password = string.Empty;

    [ObservableProperty]
    private string _displayName = string.Empty;

    [ObservableProperty]
    private string _statusMessage = string.Empty;

    [ObservableProperty]
    private bool _isBusy;

    [ObservableProperty]
    private bool _isAuthenticated;

    [ObservableProperty]
    private string _syncStatus = string.Empty;

    public AuthViewModel(IBackendApiClient backend, ISyncService sync)
    {
        _backend = backend;
        _sync = sync;
    }

    public async Task InitializeAsync()
    {
        try
        {
            await _backend.InitializeAsync();
            IsAuthenticated = _backend.IsAuthenticated;
            StatusMessage = IsAuthenticated ? "Signed in (token restored)." : "Not signed in — offline local mode.";
        }
        catch (Exception ex)
        {
            IsAuthenticated = false;
            StatusMessage = $"Auth init failed: {ex.Message}";
        }
    }

    [RelayCommand]
    private async Task LoginAsync()
    {
        if (string.IsNullOrWhiteSpace(Email) || string.IsNullOrWhiteSpace(Password))
        {
            StatusMessage = "Email and password are required.";
            return;
        }

        IsBusy = true;
        try
        {
            var ok = await _backend.LoginAsync(Email.Trim(), Password);
            IsAuthenticated = ok;
            StatusMessage = ok ? "Signed in successfully." : "Login failed (check credentials or network).";
            if (ok)
            {
                Password = string.Empty;
                await SyncNowAsync();
            }
        }
        catch (Exception ex)
        {
            IsAuthenticated = false;
            StatusMessage = $"Login error: {ex.Message}";
        }
        finally
        {
            IsBusy = false;
        }
    }

    [RelayCommand]
    private async Task RegisterAsync()
    {
        if (string.IsNullOrWhiteSpace(Email) || string.IsNullOrWhiteSpace(Password))
        {
            StatusMessage = "Email and password are required.";
            return;
        }

        IsBusy = true;
        try
        {
            var name = string.IsNullOrWhiteSpace(DisplayName) ? Email.Split('@')[0] : DisplayName.Trim();
            var ok = await _backend.RegisterAsync(Email.Trim(), Password, name);
            StatusMessage = ok
                ? "Account created. Sign in to continue."
                : "Registration failed (network or email already used).";
        }
        catch (Exception ex)
        {
            StatusMessage = $"Registration error: {ex.Message}";
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
            StatusMessage = "Signed out.";
            SyncStatus = string.Empty;
        }
        catch (Exception ex)
        {
            StatusMessage = $"Logout error: {ex.Message}";
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
        }
        catch (Exception ex)
        {
            SyncStatus = $"Sync failed: {ex.Message}";
            StatusMessage = SyncStatus;
        }
        finally
        {
            IsBusy = false;
        }
    }
}
