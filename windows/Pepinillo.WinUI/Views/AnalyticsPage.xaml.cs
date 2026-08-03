using Microsoft.UI.Xaml.Controls;
using Pepinillo.Core.ViewModels;

namespace Pepinillo.WinUI.Views;

public sealed partial class AnalyticsPage : Page
{
    public AnalyticsViewModel ViewModel { get; } = new();

    public AnalyticsPage()
    {
        this.InitializeComponent();
        this.Loaded += (_, _) => RefreshMetrics();
        ViewModel.PropertyChanged += (_, _) => RefreshMetrics();
    }

    private void RefreshMetrics()
    {
        TodayFocusText.Text = $"{ViewModel.TodayFocusMinutes} min";
        WeeklyFocusText.Text = $"{ViewModel.WeeklyFocusHours} hrs";
        StreakText.Text = $"{ViewModel.CurrentStreakDays} días";
        AiReportText.Text = ViewModel.AiReportSummary;
    }
}

