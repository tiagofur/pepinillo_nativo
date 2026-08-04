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
        ApplyNavigationLabels();

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
            NavView.Header = L("Nav.Settings", "Settings");
            return;
        }

        if (args.InvokedItemContainer is NavigationViewItem item && item.Tag is string tag)
        {
            NavigateToTag(tag);
            NavView.Header = item.Content?.ToString() ?? tag;
        }
    }

    /// <summary>
    /// Applies EN/ES/PT labels to shell NavigationView items from <see cref="ILocalizationService"/>.
    /// Call after language change (e.g. Settings save) so the shell updates without full restart.
    /// </summary>
    public void ApplyNavigationLabels()
    {
        try
        {
            var localizer = App.Services.GetRequiredService<ILocalizationService>();
            foreach (var obj in NavView.MenuItems)
            {
                if (obj is not NavigationViewItem item || item.Tag is not string tag)
                    continue;
                item.Content = tag switch
                {
                    "Focus" => localizer.GetString("Nav.Focus"),
                    "Tasks" => localizer.GetString("Nav.Tasks"),
                    "Analytics" => localizer.GetString("Nav.Analytics"),
                    "Soundscapes" => localizer.GetString("Nav.Soundscapes"),
                    "Account" => localizer.GetString("Nav.Account"),
                    _ => item.Content
                };
            }

            foreach (var obj in NavView.FooterMenuItems)
            {
                if (obj is not NavigationViewItem item || item.Tag is not string tag)
                    continue;
                if (tag == "Paywall")
                    item.Content = localizer.GetString("Nav.Upgrade");
            }
        }
        catch (Exception ex)
        {
            System.Diagnostics.Debug.WriteLine($"Nav localization failed: {ex.Message}");
        }
    }

    /// <summary>
    /// Hides the navigation pane during first-run onboarding.
    /// </summary>
    public void EnterOnboardingMode()
    {
        NavView.IsPaneVisible = false;
        NavView.IsSettingsVisible = false;
        NavView.Header = L("Nav.Welcome", "Welcome");
    }

    /// <summary>
    /// Restores the normal shell after onboarding completes or is skipped.
    /// </summary>
    public void ExitOnboardingMode()
    {
        NavView.IsPaneVisible = true;
        NavView.IsSettingsVisible = true;
        ApplyNavigationLabels();
        if (string.IsNullOrWhiteSpace(NavView.Header?.ToString())
            || string.Equals(NavView.Header?.ToString(), "Welcome", StringComparison.Ordinal)
            || string.Equals(NavView.Header?.ToString(), L("Nav.Welcome", "Welcome"), StringComparison.Ordinal))
        {
            NavView.Header = L("Nav.Focus", "Focus");
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
                NavView.Header = L("Nav.Welcome", "Welcome");
                break;
            case "Focus":
                ContentFrame.Navigate(typeof(FocusPage));
                NavView.Header = L("Nav.Focus", "Focus");
                break;
            case "Tasks":
                ContentFrame.Navigate(typeof(TasksPage));
                NavView.Header = L("Nav.Tasks", "Tasks");
                break;
            case "Analytics":
                ContentFrame.Navigate(typeof(AnalyticsPage));
                NavView.Header = L("Nav.Analytics", "Analytics");
                break;
            case "Soundscapes":
                ContentFrame.Navigate(typeof(SoundscapesPage));
                NavView.Header = L("Nav.Soundscapes", "Soundscapes");
                break;
            case "Account":
                ContentFrame.Navigate(typeof(AccountPage));
                NavView.Header = L("Nav.Account", "Account");
                break;
            case "Paywall":
                ContentFrame.Navigate(typeof(PaywallPage));
                NavView.Header = L("Nav.Upgrade", "Upgrade");
                break;
            case "Settings":
                ContentFrame.Navigate(typeof(SettingsPage));
                NavView.Header = L("Nav.Settings", "Settings");
                break;
            default:
                ContentFrame.Navigate(typeof(FocusPage));
                NavView.Header = L("Nav.Focus", "Focus");
                break;
        }
    }

    private static string L(string key, string fallback)
    {
        try
        {
            return App.Services.GetRequiredService<ILocalizationService>().GetString(key);
        }
        catch
        {
            return fallback;
        }
    }
}
