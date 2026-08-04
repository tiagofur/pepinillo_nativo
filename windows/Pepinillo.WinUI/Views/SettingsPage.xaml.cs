using System;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Pepinillo.Core.Models;
using Pepinillo.Core.Services;
using Pepinillo.Core.ViewModels;
using Pepinillo.WinUI.Services;
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
        ViewModel.OnboardingReplayRequested += OnOnboardingReplayRequested;
        Loaded += async (_, _) => await ViewModel.LoadAsync();
        Unloaded += (_, _) =>
        {
            ViewModel.SettingsSaved -= OnSettingsSaved;
            ViewModel.PremiumFeatureRequested -= OnPremiumFeatureRequested;
            ViewModel.OnboardingReplayRequested -= OnOnboardingReplayRequested;
        };
    }

    private async void OnSettingsSaved(object? sender, UserSettings settings)
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

        try
        {
            var hotkeys = App.Services.GetRequiredService<IGlobalHotkeyService>();
            hotkeys.RefreshFromSettings();
        }
        catch
        {
            // ignore
        }

        try
        {
            var startup = App.Services.GetRequiredService<IWindowsStartupService>();
            await startup.ApplyAsync(settings.LaunchAtWindowsStartup);
            ViewModel.StatusMessage = string.IsNullOrWhiteSpace(startup.LastStatus)
                ? ViewModel.StatusMessage
                : $"{ViewModel.StatusMessage} · {startup.LastStatus}";
        }
        catch
        {
            // ignore
        }

        try
        {
            var assist = App.Services.GetRequiredService<IFocusAssistService>();
            ViewModel.FocusAssistStatus = assist.FocusAssistStatus;
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

    private void OnOnboardingReplayRequested(object? sender, EventArgs e)
    {
        if (App.MainWindowInstance is MainWindow main)
        {
            main.EnterOnboardingMode();
            main.NavigateToTag("Onboarding");
        }
        else
        {
            Frame?.Navigate(typeof(OnboardingPage));
        }
    }
}
