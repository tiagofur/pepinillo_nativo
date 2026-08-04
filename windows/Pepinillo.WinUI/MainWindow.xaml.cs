using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Pepinillo.WinUI.Views;

namespace Pepinillo.WinUI;

public sealed partial class MainWindow : Window
{
    public MainWindow()
    {
        InitializeComponent();
        Title = "Pepinillo — Deep Work OS";
    }

    private void NavView_Loaded(object sender, RoutedEventArgs e)
    {
        NavigateTo("Focus");
    }

    private void NavView_ItemInvoked(NavigationView sender, NavigationViewItemInvokedEventArgs args)
    {
        if (args.IsSettingsInvoked)
        {
            NavigateTo("Settings");
            NavView.Header = "Settings";
            return;
        }

        if (args.InvokedItemContainer is NavigationViewItem item && item.Tag is string tag)
        {
            NavigateTo(tag);
            NavView.Header = item.Content?.ToString() ?? tag;
        }
    }

    private void NavigateTo(string tag)
    {
        switch (tag)
        {
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
