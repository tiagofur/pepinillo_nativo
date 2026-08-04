using System;
using System.Collections.ObjectModel;
using System.Threading.Tasks;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using Pepinillo.Core.Models;
using Pepinillo.Core.Services;

namespace Pepinillo.Core.ViewModels;

public partial class AnalyticsViewModel : ObservableObject
{
    private readonly IFocusSessionService _sessionService;
    private readonly IEntitlementService? _entitlements;
    private readonly IReflectService? _reflectService;
    private readonly IExportService? _exportService;
    private readonly IStreakProtectionService? _streakProtection;

    /// <summary>Raised when free user requests a premium Analytics feature (shell navigates to paywall).</summary>
    public event EventHandler<string>? PremiumFeatureRequested;

    /// <summary>
    /// Raised when premium export bytes are ready for the shell to open a FileSavePicker.
    /// Args: (fileExtensionWithoutDot, suggestedFileName, bytes).
    /// </summary>
    public event EventHandler<(string Extension, string SuggestedName, byte[] Bytes)>? ExportFileReady;

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
    private ObservableCollection<AchievementProgress> _achievements = new();

    [ObservableProperty]
    private PeriodReviewSummary? _weeklyReview;

    [ObservableProperty]
    private PeriodReviewSummary? _monthlyReview;

    [ObservableProperty]
    private bool _canViewPeriodReviews;

    [ObservableProperty]
    private bool _showReviewPaywallTeaser;

    [ObservableProperty]
    private int _historyWindowDays = EntitlementService.FreeAnalyticsHistoryDays;

    [ObservableProperty]
    private bool _canExport;

    [ObservableProperty]
    private string _streakProtectionCaption = string.Empty;

    [ObservableProperty]
    private bool _streakProtectionApplied;

    [ObservableProperty]
    private string _exportStatusMessage = string.Empty;

    public AnalyticsViewModel(
        IFocusSessionService sessionService,
        IEntitlementService? entitlements = null,
        IReflectService? reflectService = null,
        IExportService? exportService = null,
        IStreakProtectionService? streakProtection = null)
    {
        _sessionService = sessionService;
        _entitlements = entitlements;
        _reflectService = reflectService;
        _exportService = exportService;
        _streakProtection = streakProtection;
    }

    public async Task LoadAsync()
    {
        var utcNow = DateTime.UtcNow;
        var today = utcNow.Date;

        // Free: clamp analytics history to 7 days; Plus: unrestricted recent + wider window.
        var isPremium = _entitlements?.IsPremium == true;
        CanExport = _entitlements?.CanExport == true;
        CanViewPeriodReviews = isPremium;
        ShowReviewPaywallTeaser = !isPremium;
        HistoryWindowDays = isPremium ? 30 : EntitlementService.FreeAnalyticsHistoryDays;
        var rangeStart = today.AddDays(-(HistoryWindowDays - 1));

        TodayFocusMinutes = await _sessionService.GetTodayFocusMinutesAsync(utcNow);
        var rangeSeconds = await _sessionService.GetTotalFocusSecondsAsync(rangeStart, today.AddDays(1));
        SevenDayFocusHours = Math.Round(rangeSeconds / 3600.0, 1);
        WeeklyFocusHours = (int)Math.Floor(SevenDayFocusHours);

        var (current, best, protectionApplied) = await _sessionService.GetStreaksAsync(today);
        CurrentStreakDays = current;
        BestStreakDays = best;
        StreakProtectionApplied = protectionApplied;

        if (_streakProtection != null)
        {
            var status = await _streakProtection.GetStatusAsync(utcNow);
            StreakProtectionCaption = protectionApplied
                ? status.Caption + " · Applied to current streak"
                : status.Caption;
        }
        else
        {
            StreakProtectionCaption = isPremium
                ? "Streak protection: available (1 / week)"
                : "Upgrade for streak protection (1 skip / week)";
        }

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

        // Achievements are FREE — always load when Reflect service is available.
        if (_reflectService != null)
        {
            var achievements = await _reflectService.GetAchievementsAsync(utcNow);
            Achievements = new ObservableCollection<AchievementProgress>(achievements);

            WeeklyReview = await _reflectService.GetWeeklyReviewAsync(utcNow, includeDetails: isPremium);
            MonthlyReview = await _reflectService.GetMonthlyReviewAsync(utcNow, includeDetails: isPremium);
        }
        else
        {
            Achievements = new ObservableCollection<AchievementProgress>();
            WeeklyReview = null;
            MonthlyReview = null;
        }

        HasSessionData = TodayFocusMinutes > 0 || SevenDayFocusHours > 0 || RecentSessions.Count > 0;
        EmptyStateMessage = HasSessionData
            ? string.Empty
            : "No focus history yet. Finish a Pomodoro or Stopwatch session — stats and streaks will show up here.";
        AiReportSummary = BuildInsightSummary();
        ExportStatusMessage = string.Empty;
    }

    [RelayCommand]
    private void OpenReviewPaywall()
    {
        PremiumFeatureRequested?.Invoke(this, "period_review");
    }

    [RelayCommand]
    private async Task ExportCsvAsync()
    {
        await ExportAsync("csv").ConfigureAwait(true);
    }

    [RelayCommand]
    private async Task ExportPdfAsync()
    {
        await ExportAsync("pdf").ConfigureAwait(true);
    }

    private async Task ExportAsync(string format)
    {
        ExportStatusMessage = string.Empty;

        if (_entitlements?.CanExport != true)
        {
            PremiumFeatureRequested?.Invoke(this, "export");
            ExportStatusMessage = "Export is a Pepinillo+ feature.";
            return;
        }

        if (_exportService == null)
        {
            ExportStatusMessage = "Export service is unavailable.";
            return;
        }

        var utcNow = DateTime.UtcNow;
        var today = utcNow.Date;
        // Premium: last 365 days of completed sessions.
        var rangeStart = today.AddDays(-364);
        var sessions = await _sessionService.GetSessionsInRangeAsync(rangeStart, today.AddDays(1)).ConfigureAwait(true);
        // Oldest first for readable exports.
        sessions.Sort((a, b) => a.StartedAt.CompareTo(b.StartedAt));

        var stamp = utcNow.ToString("yyyyMMdd");
        if (format == "csv")
        {
            var csv = _exportService.BuildSessionsCsv(sessions);
            var bytes = ExportService.GetCsvBytes(csv);
            ExportFileReady?.Invoke(this, ("csv", $"pepinillo-sessions-{stamp}.csv", bytes));
            ExportStatusMessage = sessions.Count == 0
                ? "CSV ready (no sessions in range)."
                : $"CSV ready ({sessions.Count} sessions).";
        }
        else
        {
            var bytes = _exportService.BuildSessionsPdfSimple(sessions);
            ExportFileReady?.Invoke(this, ("pdf", $"pepinillo-sessions-{stamp}.pdf", bytes));
            ExportStatusMessage = sessions.Count == 0
                ? "PDF ready (no sessions in range)."
                : $"PDF ready ({sessions.Count} sessions).";
        }
    }

    private string BuildInsightSummary()
    {
        if (!HasSessionData)
            return "Your insights start after the first completed session. Full AI narrative reports unlock with Everywhere/AI+.";

        var window = HistoryWindowDays;
        var protect = StreakProtectionApplied ? " · protection applied" : string.Empty;
        return $"Last {window} days: {SevenDayFocusHours:0.#}h focus · Streak {CurrentStreakDays}d (best {BestStreakDays}d){protect}. " +
               "AI narrative reports unlock with Everywhere/AI+.";
    }
}
