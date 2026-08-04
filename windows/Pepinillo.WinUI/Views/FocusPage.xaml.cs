using System;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Pepinillo.Core.Models;
using Pepinillo.Core.ViewModels;
using Pepinillo.WinUI.Services;

namespace Pepinillo.WinUI.Views;

public sealed partial class FocusPage : Page
{
    public FocusViewModel ViewModel { get; }

    public FocusPage()
    {
        ViewModel = App.Services.GetRequiredService<FocusViewModel>();
        InitializeComponent();
        Loaded += FocusPage_Loaded;
        Unloaded += FocusPage_Unloaded;
        ViewModel.PremiumFeatureRequested += OnPremiumFeatureRequested;
    }

    private async void FocusPage_Loaded(object sender, RoutedEventArgs e)
    {
        await ViewModel.InitializeAsync();
    }

    private void FocusPage_Unloaded(object sender, RoutedEventArgs e)
    {
        ViewModel.PremiumFeatureRequested -= OnPremiumFeatureRequested;
    }

    private void OnPremiumFeatureRequested(object? sender, string feature)
    {
        // Navigate shell Frame to paywall when free tier hits a premium mode.
        if (Frame != null)
            Frame.Navigate(typeof(PaywallPage));
    }

    private void Pomodoro_Click(object sender, RoutedEventArgs e) =>
        ViewModel.SelectModeCommand.Execute(FocusMode.Pomodoro);

    private void Stopwatch_Click(object sender, RoutedEventArgs e) =>
        ViewModel.SelectModeCommand.Execute(FocusMode.Stopwatch);

    private void Flowtime_Click(object sender, RoutedEventArgs e) =>
        ViewModel.SelectModeCommand.Execute(FocusMode.Flowtime);

    private void TimeBlock_Click(object sender, RoutedEventArgs e) =>
        ViewModel.SelectModeCommand.Execute(FocusMode.TimeBlocking);

    private void MiniTimer_Click(object sender, RoutedEventArgs e)
    {
        App.Services.GetRequiredService<IMiniTimerController>().Toggle();
    }

    private void TaskCombo_SelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        if (TaskCombo.SelectedItem is TaskItem task)
            ViewModel.LinkTaskCommand.Execute(task);
    }
}
