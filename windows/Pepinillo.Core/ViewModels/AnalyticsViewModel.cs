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
    private int _weeklyFocusHours;

    [ObservableProperty]
    private int _currentStreakDays;

    [ObservableProperty]
    private int _bestStreakDays;

    [ObservableProperty]
    private string _aiReportSummary =
        "Complete focus sessions to unlock personalized insights. Full AI reports are part of Pepinillo+.";

    [ObservableProperty]
    private ObservableCollection<FocusSession> _recentSessions = new();

    public AnalyticsViewModel(IFocusSessionService sessionService)
    {
        _sessionService = sessionService;
    }

    public async Task LoadAsync()
    {
        TodayFocusMinutes = await _sessionService.GetTodayFocusMinutesAsync();
        var recent = await _sessionService.GetRecentSessionsAsync(10);
        RecentSessions = new ObservableCollection<FocusSession>(recent);

        // Weekly hours / streaks are approximate for P0 (real analytics in P2).
        var totalSeconds = 0;
        foreach (var s in recent)
            totalSeconds += s.ElapsedSeconds;
        WeeklyFocusHours = totalSeconds / 3600;
    }
}
