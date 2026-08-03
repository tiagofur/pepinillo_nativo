using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using Pepinillo.Core.Models;

namespace Pepinillo.Core.ViewModels;

public partial class SettingsViewModel : ObservableObject
{
    [ObservableProperty]
    private UserSettings _settings = new();

    [RelayCommand]
    private void SaveSettings()
    {
        // Persists updated settings to local storage
    }

    [RelayCommand]
    private void SelectTheme(string themeName)
    {
        Settings.SelectedTheme = themeName;
        OnPropertyChanged(nameof(Settings));
    }
}
