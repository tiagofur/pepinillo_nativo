using System;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Pepinillo.Core.Models;
using Pepinillo.Core.ViewModels;

namespace Pepinillo.WinUI.Views;

public sealed partial class CalendarPage : Page
{
    public CalendarViewModel ViewModel { get; }

    public CalendarPage()
    {
        ViewModel = App.Services.GetRequiredService<CalendarViewModel>();
        InitializeComponent();
        Loaded += CalendarPage_Loaded;
        Unloaded += CalendarPage_Unloaded;
        ViewModel.PremiumFeatureRequested += OnPremiumFeatureRequested;
        ViewModel.NavigateToFocusRequested += OnNavigateToFocusRequested;
    }

    private async void CalendarPage_Loaded(object sender, RoutedEventArgs e)
    {
        await ViewModel.LoadDayAsync();
    }

    private void CalendarPage_Unloaded(object sender, RoutedEventArgs e)
    {
        ViewModel.PremiumFeatureRequested -= OnPremiumFeatureRequested;
        ViewModel.NavigateToFocusRequested -= OnNavigateToFocusRequested;
    }

    private void OnPremiumFeatureRequested(object? sender, string feature)
    {
        if (Frame != null)
            Frame.Navigate(typeof(PaywallPage));
    }

    private void OnNavigateToFocusRequested(object? sender, EventArgs e)
    {
        if (App.MainWindowInstance is MainWindow main)
        {
            main.NavigateToTag("Focus");
            return;
        }

        Frame?.Navigate(typeof(FocusPage));
    }

    private async void AddAtHour_Click(object sender, RoutedEventArgs e)
    {
        if (sender is FrameworkElement { Tag: int hour })
            await ViewModel.CreateAtHourCommand.ExecuteAsync(hour);
    }

    private void StartBlock_Click(object sender, RoutedEventArgs e)
    {
        if (sender is FrameworkElement { Tag: CalendarBlockRow row })
            ViewModel.StartBlockCommand.Execute(row);
    }

    private async void DeleteBlock_Click(object sender, RoutedEventArgs e)
    {
        if (sender is FrameworkElement { Tag: CalendarBlockRow row })
            await ViewModel.DeleteBlockCommand.ExecuteAsync(row);
    }
}
