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
    private readonly IEntitlementService? _entitlements;

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

    /// <summary>Friendly empty-state when there are no completed sessions yet.</summary>
    [ObservableProperty]
    private string _emptyStateMessage = string.Empty;

    [ObservableProperty]
    private bool _hasSessionData;

    [ObservableProperty]
    private ObservableCollection<FocusSession> _recentSessions = new();

    [ObservableProperty]
    private ObservableCollection<ModeBreakdownItem> _modeBreakdown = new();

    [ObservableProperty]
    private int _historyWindowDays = EntitlementService.FreeAnalyticsHistoryDays;

    public AnalyticsViewModel(
        IFocusSessionService sessionService,
        IEntitlementService? entitlements = null)
    {
        _sessionService = sessionService;
        _entitlements = entitlements;
    }

    public async Task LoadAsync()
    {
        var utcNow = DateTime.UtcNow;
        var today = utcNow.Date;

        // Free: clamp analytics history to 7 days; Plus: unrestricted recent + wider window.
        var isPremium = _entitlements?.IsPremium == true;
        HistoryWindowDays = isPremium ? 30 : EntitlementService.FreeAnalyticsHistoryDays;
        var rangeStart = today.AddDays(-(HistoryWindowDays - 1));

        TodayFocusMinutes = await _sessionService.GetTodayFocusMinutesAsync(utcNow);
        var rangeSeconds = await _sessionService.GetTotalFocusSecondsAsync(rangeStart, today.AddDays(1));
        SevenDayFocusHours = Math.Round(rangeSeconds / 3600.0, 1);
        WeeklyFocusHours = (int)Math.Floor(SevenDayFocusHours);

        var (current, best) = await _sessionService.GetStreaksAsync(today);
        CurrentStreakDays = current;
        BestStreakDays = best;

        var breakdown = await _sessionService.GetModeBreakdownAsync(rangeStart, today.AddDays(1));
        ModeBreakdown = new ObservableCollection<ModeBreakdownItem>(breakdown);

        var recentLimit = isPremium ? 50 : 15;
        var recent = await _sessionService.GetRecentSessionsAsync(recentLimit);
        if (!isPremium)
        {
            var freeCutoff = today.AddDays(-(EntitlementService.FreeAnalyticsHistoryDays - 1));
            recent = recent.FindAll(s => s.StartedAt.Date >= freeCutoff);
        }

        RecentSessions = new ObservableCollection<FocusSession>(recent);

        HasSessionData = TodayFocusMinutes > 0 || SevenDayFocusHours > 0 || RecentSessions.Count > 0;
        EmptyStateMessage = HasSessionData
            ? string.Empty
            : "No focus history yet. Finish a Pomodoro or Stopwatch session — stats and streaks will show up here.";
        AiReportSummary = BuildInsightSummary();
    }

    private string BuildInsightSummary()
    {
        if (!HasSessionData)
            return "Your insights start after the first completed session. Full AI narrative reports unlock with Everywhere/AI+.";

        var window = HistoryWindowDays;
        return $"Last {window} days: {SevenDayFocusHours:0.#}h focus · Streak {CurrentStreakDays}d (best {BestStreakDays}d). " +
               "AI narrative reports unlock with Everywhere/AI+.";
    }
}
