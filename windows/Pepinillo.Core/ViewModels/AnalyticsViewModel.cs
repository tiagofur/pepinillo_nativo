using System;
using System.Collections.ObjectModel;
using System.Threading.Tasks;
using CommunityToolkit.Mvvm.ComponentModel;
using Pepinillo.Core.Models;
using Pepinillo.Core.Services;

namespace Pepinillo.Core.ViewModels;

public partial class AnalyticsViewModel : ObservableObject
{
    private readonly IFocusSessionService _sessionService;

    [ObservableProperty]
    private int _todayFocusMinutes;

    [ObservableProperty]
    private double _sevenDayFocusHours;

    [ObservableProperty]
    private int _weeklyFocusHours;

    [ObservableProperty]
    private int _currentStreakDays;

    [ObservableProperty]
    private int _bestStreakDays;

    [ObservableProperty]
    private string _aiReportSummary =
        "Complete focus sessions to unlock personalized insights. Full AI reports are part of Everywhere/AI+.";

    [ObservableProperty]
    private ObservableCollection<FocusSession> _recentSessions = new();

    [ObservableProperty]
    private ObservableCollection<ModeBreakdownItem> _modeBreakdown = new();

    public AnalyticsViewModel(IFocusSessionService sessionService)
    {
        _sessionService = sessionService;
    }

    public async Task LoadAsync()
    {
        var utcNow = DateTime.UtcNow;
        var today = utcNow.Date;
        var weekStart = today.AddDays(-6);

        TodayFocusMinutes = await _sessionService.GetTodayFocusMinutesAsync(utcNow);
        var sevenDaySeconds = await _sessionService.GetTotalFocusSecondsAsync(weekStart, today.AddDays(1));
        SevenDayFocusHours = Math.Round(sevenDaySeconds / 3600.0, 1);
        WeeklyFocusHours = (int)Math.Floor(SevenDayFocusHours);

        var (current, best) = await _sessionService.GetStreaksAsync(today);
        CurrentStreakDays = current;
        BestStreakDays = best;

        var breakdown = await _sessionService.GetModeBreakdownAsync(weekStart, today.AddDays(1));
        ModeBreakdown = new ObservableCollection<ModeBreakdownItem>(breakdown);

        var recent = await _sessionService.GetRecentSessionsAsync(15);
        RecentSessions = new ObservableCollection<FocusSession>(recent);

        AiReportSummary = BuildInsightSummary();
    }

    private string BuildInsightSummary()
    {
        if (TodayFocusMinutes <= 0 && SevenDayFocusHours <= 0)
            return "Complete focus sessions to unlock personalized insights. Full AI reports are part of Everywhere/AI+.";

        return $"Last 7 days: {SevenDayFocusHours:0.#}h focus · Streak {CurrentStreakDays}d (best {BestStreakDays}d). " +
               "AI narrative reports unlock with Everywhere/AI+.";
    }
}
