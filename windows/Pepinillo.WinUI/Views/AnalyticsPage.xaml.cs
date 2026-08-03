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
        WeeklyFocusText.Text = $"{ViewModel.WeeklyFocusHours} hrs";
        StreakText.Text = $"{ViewModel.CurrentStreakDays} days";
        AiReportText.Text = ViewModel.AiReportSummary;
    }
}
