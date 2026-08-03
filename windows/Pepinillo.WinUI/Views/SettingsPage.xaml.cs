using Microsoft.Extensions.DependencyInjection;
using Microsoft.UI.Xaml.Controls;
using Pepinillo.Core.Models;
using Pepinillo.Core.ViewModels;

namespace Pepinillo.WinUI.Views;

public sealed partial class SettingsPage : Page
{
    public SettingsViewModel ViewModel { get; }

    public SettingsPage()
    {
        ViewModel = App.Services.GetRequiredService<SettingsViewModel>();
        InitializeComponent();
        ViewModel.SettingsSaved += OnSettingsSaved;
        Loaded += async (_, _) => await ViewModel.LoadAsync();
        Unloaded += (_, _) => ViewModel.SettingsSaved -= OnSettingsSaved;
    }

    private void OnSettingsSaved(object? sender, UserSettings settings)
    {
        ThemeHelper.ApplyTheme(settings.SelectedTheme, App.MainWindowInstance);
    }
}
