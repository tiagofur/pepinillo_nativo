using System;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Pepinillo.Core.Models;
using Pepinillo.Core.ViewModels;
using Windows.System;

namespace Pepinillo.WinUI.Views;

public sealed partial class SettingsPage : Page
{
    public SettingsViewModel ViewModel { get; }

    public SettingsPage()
    {
        ViewModel = App.Services.GetRequiredService<SettingsViewModel>();
        InitializeComponent();
        ViewModel.SettingsSaved += OnSettingsSaved;
        ViewModel.PremiumFeatureRequested += OnPremiumFeatureRequested;
        Loaded += async (_, _) => await ViewModel.LoadAsync();
        Unloaded += (_, _) =>
        {
            ViewModel.SettingsSaved -= OnSettingsSaved;
            ViewModel.PremiumFeatureRequested -= OnPremiumFeatureRequested;
        };
    }

    private void OnSettingsSaved(object? sender, UserSettings settings)
    {
        ThemeHelper.ApplyTheme(
            settings.SelectedTheme,
            App.MainWindowInstance,
            useMica: settings.UseMicaBackdrop);

        try
        {
            var focus = App.Services.GetRequiredService<FocusViewModel>();
            _ = focus.RefreshSettingsAsync();
        }
        catch
        {
            // ignore
        }
    }

    private void OnPremiumFeatureRequested(object? sender, string feature)
    {
        // Mirror FocusPage: free user picking premium theme → paywall.
        if (Frame != null)
            Frame.Navigate(typeof(PaywallPage));
    }

    private async void Privacy_Click(object sender, RoutedEventArgs e)
    {
        try
        {
            await Launcher.LaunchUriAsync(new Uri("https://creapolis.dev/privacy-policy/"));
        }
        catch
        {
            // network / shell failure must not crash
        }
    }

    private async void Terms_Click(object sender, RoutedEventArgs e)
    {
        try
        {
            await Launcher.LaunchUriAsync(new Uri("https://creapolis.dev/terms-of-use/"));
        }
        catch
        {
            // ignore
        }
    }

    private void Upgrade_Click(object sender, RoutedEventArgs e)
    {
        Frame?.Navigate(typeof(PaywallPage));
    }
}
