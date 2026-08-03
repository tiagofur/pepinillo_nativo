using System;
using System.Threading.Tasks;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using Pepinillo.Core.Models;
using Pepinillo.Core.Services;

namespace Pepinillo.Core.ViewModels;

public partial class SettingsViewModel : ObservableObject
{
    private readonly ISettingsService _settingsService;

    /// <summary>
    /// Raised after settings are saved so the shell can apply theme / OS intent flags.
    /// </summary>
    public event EventHandler<UserSettings>? SettingsSaved;

    [ObservableProperty]
    private UserSettings _settings = new();

    [ObservableProperty]
    private bool _isBusy;

    [ObservableProperty]
    private string _statusMessage = string.Empty;

    [ObservableProperty]
    private int _selectedThemeIndex;

    public SettingsViewModel(ISettingsService settingsService)
    {
        _settingsService = settingsService;
    }

    public async Task LoadAsync()
    {
        IsBusy = true;
        try
        {
            Settings = await _settingsService.GetSettingsAsync();
            SelectedThemeIndex = ThemeToIndex(Settings.SelectedTheme);
            StatusMessage = string.Empty;
        }
        finally
        {
            IsBusy = false;
        }
    }

    [RelayCommand]
    private async Task SaveSettingsAsync()
    {
        IsBusy = true;
        try
        {
            Settings.SelectedTheme = IndexToTheme(SelectedThemeIndex);
            await _settingsService.SaveSettingsAsync(Settings);
            StatusMessage = "Settings saved";
            SettingsSaved?.Invoke(this, Settings);
        }
        catch (Exception ex)
        {
            StatusMessage = $"Save failed: {ex.Message}";
        }
        finally
        {
            IsBusy = false;
        }
    }

    [RelayCommand]
    private async Task SelectThemeAsync(string themeName)
    {
        if (string.IsNullOrWhiteSpace(themeName))
            return;

        Settings.SelectedTheme = themeName;
        SelectedThemeIndex = ThemeToIndex(themeName);
        OnPropertyChanged(nameof(Settings));
        await SaveSettingsAsync();
    }

    partial void OnSelectedThemeIndexChanged(int value)
    {
        Settings.SelectedTheme = IndexToTheme(value);
    }

    private static int ThemeToIndex(string theme) => theme switch
    {
        "Dark" => 1,
        "Light" => 2,
        "Forest" => 3,
        "Ocean" => 4,
        "OLEDBlack" => 5,
        _ => 0 // System
    };

    private static string IndexToTheme(int index) => index switch
    {
        1 => "Dark",
        2 => "Light",
        3 => "Forest",
        4 => "Ocean",
        5 => "OLEDBlack",
        _ => "System"
    };
}
