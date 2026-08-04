using System;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.UI.Xaml.Controls;
using Pepinillo.Core.ViewModels;

namespace Pepinillo.WinUI.Views;

public sealed partial class AnalyticsPage : Page
{
    public AnalyticsViewModel ViewModel { get; }

    public AnalyticsPage()
    {
        ViewModel = App.Services.GetRequiredService<AnalyticsViewModel>();
        InitializeComponent();
        Loaded += async (_, _) =>
        {
            await ViewModel.LoadAsync();
            RefreshMetrics();
        };
        ViewModel.PropertyChanged += (_, _) => RefreshMetrics();
    }

    private void RefreshMetrics()
    {
        TodayFocusText.Text = $"{ViewModel.TodayFocusMinutes} min";
        WeeklyFocusText.Text = $"{ViewModel.SevenDayFocusHours:0.#} h";
        StreakText.Text = $"{ViewModel.CurrentStreakDays} d";
        BestStreakText.Text = $"{ViewModel.BestStreakDays} d";
        AiReportText.Text = ViewModel.AiReportSummary;
    }
}
