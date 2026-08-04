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
    private readonly ILocalizationService? _localizer;
    private readonly ISettingsService? _settings;

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

    [ObservableProperty]
    private string _titleLabel = "Analytics";

    [ObservableProperty]
    private string _subtitleLabel =
        "Local session totals from SQLite (UTC). Charts use simple ProgressBars.";

    [ObservableProperty]
    private string _focusTodayLabel = "Focus today";

    [ObservableProperty]
    private string _sevenDayLabel = "7-day focus";

    [ObservableProperty]
    private string _currentStreakLabel = "Current streak";

    [ObservableProperty]
    private string _bestStreakLabel = "Best streak";

    [ObservableProperty]
    private string _achievementsLabel = "Achievements";

    [ObservableProperty]
    private string _exportLabel = "Export";

    [ObservableProperty]
    private string _exportCsvLabel = "Export CSV";

    [ObservableProperty]
    private string _exportPdfLabel = "Export PDF";

    [ObservableProperty]
    private string _weeklyReviewLabel = "Weekly Review";

    [ObservableProperty]
    private string _monthlyReviewLabel = "Monthly Review";

    public AnalyticsViewModel(
        IFocusSessionService sessionService,
        IEntitlementService? entitlements = null,
        IReflectService? reflectService = null,
        IExportService? exportService = null,
        IStreakProtectionService? streakProtection = null,
        ILocalizationService? localizer = null,
        ISettingsService? settings = null)
    {
        _sessionService = sessionService;
        _entitlements = entitlements;
        _reflectService = reflectService;
        _exportService = exportService;
        _streakProtection = streakProtection;
        _localizer = localizer;
        _settings = settings;
    }

    public async Task LoadAsync()
    {
        await ApplyLanguageAsync();

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
            var appliedSuffix = T("Analytics.ProtectionApplied", " · Applied to current streak");
            StreakProtectionCaption = protectionApplied
                ? status.Caption + appliedSuffix
                : status.Caption;
        }
        else
        {
            StreakProtectionCaption = isPremium
                ? T("Analytics.StreakProtectionPremium", "Streak protection: available (1 / week)")
                : T("Analytics.StreakProtectionUpgrade",
                    "Upgrade for streak protection (1 skip / week)");
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
            : T("Analytics.EmptyState",
                "No focus history yet. Finish a Pomodoro or Stopwatch session — stats and streaks will show up here.");
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
            ExportStatusMessage = T("Analytics.ExportPremium", "Export is a Pepinillo+ feature.");
            return;
        }

        if (_exportService == null)
        {
            ExportStatusMessage = T("Analytics.ExportUnavailable", "Export service is unavailable.");
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
                ? T("Analytics.ExportCsvEmpty", "CSV ready (no sessions in range).")
                : string.Format(
                    T("Analytics.ExportCsvReady", "CSV ready ({0} sessions)."),
                    sessions.Count);
        }
        else
        {
            var bytes = _exportService.BuildSessionsPdfSimple(sessions);
            ExportFileReady?.Invoke(this, ("pdf", $"pepinillo-sessions-{stamp}.pdf", bytes));
            ExportStatusMessage = sessions.Count == 0
                ? T("Analytics.ExportPdfEmpty", "PDF ready (no sessions in range).")
                : string.Format(
                    T("Analytics.ExportPdfReady", "PDF ready ({0} sessions)."),
                    sessions.Count);
        }
    }

    private string BuildInsightSummary()
    {
        if (!HasSessionData)
            return T("Analytics.InsightEmpty",
                "Your insights start after the first completed session. Full AI narrative reports unlock with Everywhere/AI+.");

        var window = HistoryWindowDays;
        var protect = StreakProtectionApplied
            ? T("Analytics.ProtectionApplied", " · Applied to current streak")
            : string.Empty;

        return string.Format(
            T("Analytics.InsightSummary",
                "Last {0} days: {1}h focus · Streak {2}d (best {3}d){4}. AI narrative reports unlock with Everywhere/AI+."),
            window,
            SevenDayFocusHours.ToString("0.#"),
            CurrentStreakDays,
            BestStreakDays,
            protect);
    }

    private async Task ApplyLanguageAsync()
    {
        if (_localizer == null) return;

        if (_settings != null)
        {
            try
            {
                var settings = await _settings.GetSettingsAsync();
                _localizer.SetLanguage(settings.PreferredLanguage);
            }
            catch
            {
                // keep current
            }
        }

        TitleLabel = T("Analytics.Title", "Analytics");
        SubtitleLabel = T("Analytics.Subtitle", SubtitleLabel);
        FocusTodayLabel = T("Analytics.FocusToday", "Focus today");
        SevenDayLabel = T("Analytics.SevenDayFocus", "7-day focus");
        CurrentStreakLabel = T("Analytics.CurrentStreak", "Current streak");
        BestStreakLabel = T("Analytics.BestStreak", "Best streak");
        AchievementsLabel = T("Analytics.Achievements", "Achievements");
        ExportLabel = T("Analytics.Export", "Export");
        ExportCsvLabel = T("Analytics.ExportCsv", "Export CSV");
        ExportPdfLabel = T("Analytics.ExportPdf", "Export PDF");
        WeeklyReviewLabel = T("Analytics.WeeklyReview", "Weekly Review");
        MonthlyReviewLabel = T("Analytics.MonthlyReview", "Monthly Review");
    }

    private string T(string key, string fallback) =>
        _localizer?.GetString(key) ?? fallback;
}
