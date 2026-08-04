using System;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Pepinillo.Core.Models;
using Pepinillo.Core.ViewModels;

namespace Pepinillo.WinUI.Views;

public sealed partial class AnalyticsPage : Page
{
    public AnalyticsViewModel ViewModel { get; }

    public AnalyticsPage()
    {
        ViewModel = App.Services.GetRequiredService<AnalyticsViewModel>();
        InitializeComponent();
        ViewModel.PremiumFeatureRequested += OnPremiumFeatureRequested;
        Loaded += async (_, _) =>
        {
            await ViewModel.LoadAsync();
            RefreshMetrics();
        };
        Unloaded += (_, _) => ViewModel.PremiumFeatureRequested -= OnPremiumFeatureRequested;
        ViewModel.PropertyChanged += (_, _) => RefreshMetrics();
    }

    private void OnPremiumFeatureRequested(object? sender, string feature)
    {
        if (Frame != null)
            Frame.Navigate(typeof(PaywallPage));
    }

    private void ReviewPaywall_Click(object sender, RoutedEventArgs e)
    {
        ViewModel.OpenReviewPaywallCommand.Execute(null);
    }

    private void RefreshMetrics()
    {
        TodayFocusText.Text = $"{ViewModel.TodayFocusMinutes} min";
        WeeklyFocusText.Text = $"{ViewModel.SevenDayFocusHours:0.#} h";
        StreakText.Text = $"{ViewModel.CurrentStreakDays} d";
        BestStreakText.Text = $"{ViewModel.BestStreakDays} d";
        AiReportText.Text = ViewModel.AiReportSummary;
        RefreshPeriodCard(
            ViewModel.WeeklyReview,
            WeeklyReviewDetailText,
            WeeklyReviewTeaserText,
            WeeklyUpgradeButton,
            ViewModel.CanViewPeriodReviews);
        RefreshPeriodCard(
            ViewModel.MonthlyReview,
            MonthlyReviewDetailText,
            MonthlyReviewTeaserText,
            MonthlyUpgradeButton,
            ViewModel.CanViewPeriodReviews);
    }

    private static void RefreshPeriodCard(
        PeriodReviewSummary? review,
        TextBlock detail,
        TextBlock teaser,
        Button upgradeButton,
        bool canView)
    {
        if (review == null)
        {
            detail.Text = string.Empty;
            detail.Visibility = Visibility.Collapsed;
            teaser.Visibility = Visibility.Collapsed;
            upgradeButton.Visibility = Visibility.Collapsed;
            return;
        }

        if (!canView || review.IsLocked)
        {
            detail.Visibility = Visibility.Collapsed;
            teaser.Text = review.TeaserMessage;
            teaser.Visibility = Visibility.Visible;
            upgradeButton.Visibility = Visibility.Visible;
            return;
        }

        teaser.Visibility = Visibility.Collapsed;
        upgradeButton.Visibility = Visibility.Collapsed;
        detail.Visibility = Visibility.Visible;
        var trend = review.TrendVsPrevious switch
        {
            1 => "↑",
            -1 => "↓",
            _ => "→"
        };
        var topMode = string.IsNullOrEmpty(review.TopModeName) ? "—" : review.TopModeName;
        detail.Text =
            $"{review.Label}: {review.FocusHours:0.#}h · {review.SessionCount} sessions · top {topMode} {trend}\n" +
            $"{review.PreviousLabel}: {review.PreviousFocusHours:0.#}h · {review.PreviousSessionCount} sessions · streak {review.CurrentStreakDays}d";
    }
}
