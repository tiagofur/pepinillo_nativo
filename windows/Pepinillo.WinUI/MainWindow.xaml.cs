using System;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Pepinillo.Core.Services;
using Pepinillo.WinUI.Views;

namespace Pepinillo.WinUI;

public sealed partial class MainWindow : Window
{
    public MainWindow()
    {
        InitializeComponent();
        Title = "Pepinillo — Deep Work OS";
    }

    private async void NavView_Loaded(object sender, RoutedEventArgs e)
    {
        var showOnboarding = false;
        try
        {
            var settings = await App.Services.GetRequiredService<ISettingsService>().GetSettingsAsync();
            showOnboarding = !settings.HasCompletedOnboarding;
        }
        catch (Exception ex)
        {
            System.Diagnostics.Debug.WriteLine($"Onboarding gate failed: {ex.Message}");
        }

        if (showOnboarding)
            EnterOnboardingMode();
        else
            ExitOnboardingMode();

        NavigateToTag(showOnboarding ? "Onboarding" : "Focus");
    }

    private void NavView_ItemInvoked(NavigationView sender, NavigationViewItemInvokedEventArgs args)
    {
        if (args.IsSettingsInvoked)
        {
            NavigateToTag("Settings");
            NavView.Header = "Settings";
            return;
        }

        if (args.InvokedItemContainer is NavigationViewItem item && item.Tag is string tag)
        {
            NavigateToTag(tag);
            NavView.Header = item.Content?.ToString() ?? tag;
        }
    }

    /// <summary>
    /// Hides the navigation pane during first-run onboarding.
    /// </summary>
    public void EnterOnboardingMode()
    {
        NavView.IsPaneVisible = false;
        NavView.IsSettingsVisible = false;
        NavView.Header = "Welcome";
    }

    /// <summary>
    /// Restores the normal shell after onboarding completes or is skipped.
    /// </summary>
    public void ExitOnboardingMode()
    {
        NavView.IsPaneVisible = true;
        NavView.IsSettingsVisible = true;
        if (string.IsNullOrWhiteSpace(NavView.Header?.ToString())
            || string.Equals(NavView.Header?.ToString(), "Welcome", StringComparison.Ordinal))
        {
            NavView.Header = "Focus";
        }
    }

    /// <summary>
    /// Public navigation entry used by pages (onboarding complete, settings replay, paywall, etc.).
    /// </summary>
    public void NavigateToTag(string tag)
    {
        switch (tag)
        {
            case "Onboarding":
                ContentFrame.Navigate(typeof(OnboardingPage));
                NavView.Header = "Welcome";
                break;
            case "Focus":
                ContentFrame.Navigate(typeof(FocusPage));
                break;
            case "Tasks":
                ContentFrame.Navigate(typeof(TasksPage));
                break;
            case "Analytics":
                ContentFrame.Navigate(typeof(AnalyticsPage));
                break;
            case "Soundscapes":
                ContentFrame.Navigate(typeof(SoundscapesPage));
                break;
            case "Account":
                ContentFrame.Navigate(typeof(AccountPage));
                break;
            case "Paywall":
                ContentFrame.Navigate(typeof(PaywallPage));
                break;
            case "Settings":
                ContentFrame.Navigate(typeof(SettingsPage));
                break;
            default:
                ContentFrame.Navigate(typeof(FocusPage));
                break;
        }
    }
}
