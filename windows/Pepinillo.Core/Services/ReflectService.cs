using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Microsoft.EntityFrameworkCore;
using Pepinillo.Core.Data;
using Pepinillo.Core.Models;

namespace Pepinillo.Core.Services;

/// <summary>
/// Local Reflect aggregates: achievements (FREE) and period reviews (premium details).
/// </summary>
public class ReflectService : IReflectService
{
    /// <summary>
    /// Early Bird uses UTC hour &lt; 7 for deterministic tests and cross-timezone stability.
    /// Product copy may still say "before 7 AM"; Windows implements UTC intentionally.
    /// </summary>
    public const int EarlyBirdUtcHourExclusive = 7;

    public const int WeeklyStreakTargetDays = 7;
    public const int PomodoroMasterTarget = 100;
    public const int DeepDiverFlowtimeSeconds = 10 * 3600;
    public const int CenturyClubTarget = 100;
    public const int EarlyBirdTarget = 10;

    private readonly PepinilloDbContext _db;
    private readonly IFocusSessionService _sessions;

    public ReflectService(PepinilloDbContext db, IFocusSessionService sessions)
    {
        _db = db;
        _sessions = sessions;
    }

    public async Task<IReadOnlyList<AchievementProgress>> GetAchievementsAsync(DateTime? utcNow = null)
    {
        var today = (utcNow ?? DateTime.UtcNow).Date;

        // Completed with positive focus time — matches product "completed session" language.
        var completedQuery = _db.FocusSessions
            .Where(s => s.IsCompleted && s.ElapsedSeconds > 0);

        var totalCompleted = await completedQuery.CountAsync();
        var pomodoroCount = await completedQuery.CountAsync(s => s.Mode == FocusMode.Pomodoro);
        var flowtimeSeconds = await completedQuery
            .Where(s => s.Mode == FocusMode.Flowtime)
            .SumAsync(s => (int?)s.ElapsedSeconds) ?? 0;

        // Early Bird: started before 07:00 UTC (documented for determinism).
        var earlyBirdCount = await completedQuery
            .CountAsync(s => s.StartedAt.Hour < EarlyBirdUtcHourExclusive);

        var (currentStreak, bestStreak) = await _sessions.GetStreaksAsync(today);
        var streakForBadge = Math.Max(currentStreak, bestStreak);

        return new List<AchievementProgress>
        {
            Build(
                id: "first_session",
                title: "First Session",
                description: "Complete your first focus session.",
                current: totalCompleted >= 1 ? 1 : 0,
                target: 1),
            Build(
                id: "weekly_streak",
                title: "Weekly Streak",
                description: "Focus on 7 consecutive days.",
                current: Math.Min(streakForBadge, WeeklyStreakTargetDays),
                target: WeeklyStreakTargetDays,
                unlockedOverride: streakForBadge >= WeeklyStreakTargetDays),
            Build(
                id: "pomodoro_master",
                title: "Pomodoro Master",
                description: "Complete 100 Pomodoro sessions.",
                current: pomodoroCount,
                target: PomodoroMasterTarget),
            Build(
                id: "deep_diver",
                title: "Deep Diver",
                description: "Accumulate 10 hours in Flowtime.",
                // Progress shown in whole hours; unlock uses full second threshold (36000).
                current: Math.Min(flowtimeSeconds / 3600, 10),
                target: 10,
                unlockedOverride: flowtimeSeconds >= DeepDiverFlowtimeSeconds),
            Build(
                id: "century_club",
                title: "Century Club",
                description: "Complete 100 focus sessions.",
                current: totalCompleted,
                target: CenturyClubTarget),
            Build(
                id: "early_bird",
                title: "Early Bird",
                description: "Start 10 sessions before 07:00 UTC.",
                current: earlyBirdCount,
                target: EarlyBirdTarget)
        };
    }

    public async Task<PeriodReviewSummary> GetWeeklyReviewAsync(DateTime? utcNow = null, bool includeDetails = true)
    {
        var now = utcNow ?? DateTime.UtcNow;
        var today = now.Date;
        var thisWeekStart = GetUtcWeekStartMonday(today);
        var thisWeekEnd = thisWeekStart.AddDays(7);
        var prevWeekStart = thisWeekStart.AddDays(-7);

        return await BuildPeriodReviewAsync(
            label: "This week",
            previousLabel: "Previous week",
            periodStart: thisWeekStart,
            periodEndExclusive: thisWeekEnd,
            previousStart: prevWeekStart,
            previousEndExclusive: thisWeekStart,
            utcToday: today,
            includeDetails: includeDetails,
            lockedTeaser: "Upgrade for Weekly Review — compare this week vs last week with trends.");
    }

    public async Task<PeriodReviewSummary> GetMonthlyReviewAsync(DateTime? utcNow = null, bool includeDetails = true)
    {
        var now = utcNow ?? DateTime.UtcNow;
        var today = now.Date;
        var thisMonthStart = new DateTime(today.Year, today.Month, 1, 0, 0, 0, DateTimeKind.Utc);
        var nextMonthStart = thisMonthStart.AddMonths(1);
        var prevMonthStart = thisMonthStart.AddMonths(-1);

        return await BuildPeriodReviewAsync(
            label: "This month",
            previousLabel: "Previous month",
            periodStart: thisMonthStart,
            periodEndExclusive: nextMonthStart,
            previousStart: prevMonthStart,
            previousEndExclusive: thisMonthStart,
            utcToday: today,
            includeDetails: includeDetails,
            lockedTeaser: "Upgrade for Monthly Review — see monthly focus hours, sessions, and top mode.");
    }

    /// <summary>
    /// Monday-start ISO-like UTC week: Monday 00:00 through next Monday 00:00 exclusive.
    /// </summary>
    public static DateTime GetUtcWeekStartMonday(DateTime utcDate)
    {
        var date = utcDate.Date;
        // Convert DayOfWeek so Monday = 0 … Sunday = 6.
        var offset = ((int)date.DayOfWeek + 6) % 7;
        return DateTime.SpecifyKind(date.AddDays(-offset), DateTimeKind.Utc);
    }

    private async Task<PeriodReviewSummary> BuildPeriodReviewAsync(
        string label,
        string previousLabel,
        DateTime periodStart,
        DateTime periodEndExclusive,
        DateTime previousStart,
        DateTime previousEndExclusive,
        DateTime utcToday,
        bool includeDetails,
        string lockedTeaser)
    {
        var (currentStreak, _) = await _sessions.GetStreaksAsync(utcToday);

        if (!includeDetails)
        {
            return new PeriodReviewSummary
            {
                Label = label,
                PreviousLabel = previousLabel,
                PeriodStartUtc = periodStart,
                PeriodEndExclusiveUtc = periodEndExclusive,
                CurrentStreakDays = currentStreak,
                IsLocked = true,
                TeaserMessage = lockedTeaser
            };
        }

        var currentSeconds = await _sessions.GetTotalFocusSecondsAsync(periodStart, periodEndExclusive);
        var previousSeconds = await _sessions.GetTotalFocusSecondsAsync(previousStart, previousEndExclusive);
        var currentBreakdown = await _sessions.GetModeBreakdownAsync(periodStart, periodEndExclusive);
        var previousBreakdown = await _sessions.GetModeBreakdownAsync(previousStart, previousEndExclusive);

        var currentCount = currentBreakdown.Sum(b => b.SessionCount);
        var previousCount = previousBreakdown.Sum(b => b.SessionCount);
        var currentHours = Math.Round(currentSeconds / 3600.0, 1);
        var previousHours = Math.Round(previousSeconds / 3600.0, 1);

        return new PeriodReviewSummary
        {
            Label = label,
            PreviousLabel = previousLabel,
            PeriodStartUtc = periodStart,
            PeriodEndExclusiveUtc = periodEndExclusive,
            FocusHours = currentHours,
            SessionCount = currentCount,
            TopModeName = currentBreakdown.FirstOrDefault()?.ModeName ?? string.Empty,
            PreviousFocusHours = previousHours,
            PreviousSessionCount = previousCount,
            PreviousTopModeName = previousBreakdown.FirstOrDefault()?.ModeName ?? string.Empty,
            TrendVsPrevious = ComputeTrend(currentHours, previousHours),
            CurrentStreakDays = currentStreak,
            IsLocked = false,
            TeaserMessage = string.Empty
        };
    }

    /// <summary>1 = up, 0 = flat, -1 = down (by focus hours, 0.05h tolerance).</summary>
    public static int ComputeTrend(double currentHours, double previousHours)
    {
        const double epsilon = 0.05;
        var delta = currentHours - previousHours;
        if (delta > epsilon)
            return 1;
        if (delta < -epsilon)
            return -1;
        return 0;
    }

    private static AchievementProgress Build(
        string id,
        string title,
        string description,
        int current,
        int target,
        bool? unlockedOverride = null)
    {
        var clampedCurrent = Math.Max(0, current);
        return new AchievementProgress
        {
            Id = id,
            Title = title,
            Description = description,
            ProgressCurrent = clampedCurrent,
            ProgressTarget = target,
            IsUnlocked = unlockedOverride ?? clampedCurrent >= target
        };
    }
}
