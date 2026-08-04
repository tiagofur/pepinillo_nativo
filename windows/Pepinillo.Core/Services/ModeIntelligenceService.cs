using System;
using System.Collections.Generic;
using System.Linq;
using Pepinillo.Core.Models;

namespace Pepinillo.Core.Services;

/// <summary>
/// Port of iOS <c>ModeIntelligenceService</c> with Windows global time-of-day fallback.
/// Task path: min 3 completed sessions, score = completionRate×0.6 + avgDurationNorm×0.4,
/// confidence ≥ 0.7 and margin ≥ 0.1 over second best.
/// Energy path: min 5 sessions for same energy tasks (completion-rate winner).
/// Global path: last 30 days, prefer same UTC hour ±2h when ≥3, else all recent; min 5.
/// </summary>
public sealed class ModeIntelligenceService : IModeIntelligenceService
{
    public const int TaskMinimumSessions = 3;
    public const int EnergyMinimumSessions = 5;
    public const int GlobalMinimumSessions = 5;
    public const int GlobalLookbackDays = 30;
    public const int HourBucketHalfWidth = 2;
    public const double MinConfidence = 0.7;
    public const double MinMargin = 0.1;

    public ModeSuggestion? Suggest(
        IReadOnlyList<FocusSession> sessions,
        Guid? taskId,
        string? taskEnergy,
        DateTime utcNow,
        bool isPremium,
        IReadOnlyDictionary<Guid, string>? taskEnergyById = null)
    {
        ArgumentNullException.ThrowIfNull(sessions);

        ModeSuggestion? raw = null;

        if (taskId is Guid tid)
        {
            raw = SuggestForTask(sessions, tid, TaskMinimumSessions);
        }

        if (raw == null
            && !string.IsNullOrWhiteSpace(taskEnergy)
            && taskEnergyById is { Count: > 0 })
        {
            raw = SuggestForEnergy(sessions, taskEnergy.Trim(), taskEnergyById, EnergyMinimumSessions);
        }

        if (raw == null)
        {
            raw = SuggestGlobal(sessions, utcNow, GlobalMinimumSessions);
        }

        if (raw == null)
            return null;

        if (isPremium)
            return raw;

        // Free: locked teaser — caller must not apply the mode.
        return new ModeSuggestion
        {
            SuggestedMode = raw.SuggestedMode,
            Confidence = raw.Confidence,
            Reason = raw.Reason,
            Source = raw.Source,
            IsLocked = true
        };
    }

    /// <summary>Task-linked scoring (iOS-aligned).</summary>
    public ModeSuggestion? SuggestForTask(
        IReadOnlyList<FocusSession> sessions,
        Guid taskId,
        int minimumSessions = TaskMinimumSessions)
    {
        // iOS: filter completed sessions for this task only.
        var taskSessions = sessions
            .Where(s => s.IsCompleted && s.TaskItemId == taskId)
            .ToList();

        return ScoreWeighted(
            taskSessions,
            minimumSessions,
            ModeSuggestionSource.Task,
            best =>
            {
                var stats = BuildStats(taskSessions)[best];
                var avgMinutes = (int)(stats.AverageDurationSeconds / 60.0);
                var pct = (int)(stats.CompletionRate * 100);
                return $"You complete {pct}% of sessions in {ModeDisplayName(best)} (avg {avgMinutes}m)";
            });
    }

    /// <summary>Energy-level path (iOS suggestModeForEnergyLevel).</summary>
    public ModeSuggestion? SuggestForEnergy(
        IReadOnlyList<FocusSession> sessions,
        string energyLevel,
        IReadOnlyDictionary<Guid, string> taskEnergyById,
        int minimumSessions = EnergyMinimumSessions)
    {
        var normalized = energyLevel.Trim();
        if (string.IsNullOrEmpty(normalized))
            return null;

        var matchingTaskIds = taskEnergyById
            .Where(kv => string.Equals(kv.Value?.Trim(), normalized, StringComparison.OrdinalIgnoreCase))
            .Select(kv => kv.Key)
            .ToHashSet();

        if (matchingTaskIds.Count == 0)
            return null;

        var relevant = sessions
            .Where(s => s.IsCompleted
                        && s.TaskItemId is Guid tid
                        && matchingTaskIds.Contains(tid))
            .ToList();

        if (relevant.Count < minimumSessions)
            return null;

        var modeStats = BuildStats(relevant);
        if (modeStats.Count == 0)
            return null;

        // iOS energy path: max completion rate only (not weighted duration score).
        var best = modeStats.OrderByDescending(kv => kv.Value.CompletionRate).First();
        var confidence = best.Value.CompletionRate;
        if (confidence < MinConfidence)
            return null;

        var energyLabel = EnergyDisplayName(normalized);
        return new ModeSuggestion
        {
            SuggestedMode = best.Key,
            Confidence = confidence,
            Reason = $"{energyLabel} tasks go best with {ModeDisplayName(best.Key)}",
            Source = ModeSuggestionSource.Energy,
            IsLocked = false
        };
    }

    /// <summary>Global / time-of-day fallback (Windows enhancement).</summary>
    public ModeSuggestion? SuggestGlobal(
        IReadOnlyList<FocusSession> sessions,
        DateTime utcNow,
        int minimumSessions = GlobalMinimumSessions)
    {
        var windowStart = utcNow.AddDays(-GlobalLookbackDays);
        var recent = sessions
            .Where(s => s.IsCompleted && s.StartedAt >= windowStart && s.StartedAt <= utcNow.AddDays(1))
            .ToList();

        if (recent.Count == 0)
            return null;

        var hour = utcNow.Hour;
        // Prefer same UTC hour ±2h when the bucket has enough sessions (≥ min, which is ≥3).
        // Otherwise score all recent completed sessions in the lookback window.
        var sameBucket = recent
            .Where(s => HourDistance(s.StartedAt.Hour, hour) <= HourBucketHalfWidth)
            .ToList();

        var useHourBucket = sameBucket.Count >= minimumSessions;
        var pool = useHourBucket ? sameBucket : recent;
        if (pool.Count < minimumSessions)
            return null;

        return ScoreWeighted(
            pool,
            minimumSessions,
            ModeSuggestionSource.Global,
            best => useHourBucket
                ? $"Around this time you often do well with {ModeDisplayName(best)}"
                : $"Lately you often do well with {ModeDisplayName(best)}");
    }

    private static ModeSuggestion? ScoreWeighted(
        IReadOnlyList<FocusSession> pool,
        int minimumSessions,
        ModeSuggestionSource source,
        Func<FocusMode, string> reasonFactory)
    {
        if (pool.Count < minimumSessions)
            return null;

        var modeStats = BuildStats(pool);
        if (modeStats.Count == 0)
            return null;

        // With only completed sessions (iOS filter), completionRate is always 1.0 per mode present.
        // Still apply the formula for parity and future incomplete-session pools.
        var maxAvg = modeStats.Values.Select(s => s.AverageDurationSeconds).DefaultIfEmpty(1).Max();
        if (maxAvg <= 0)
            maxAvg = 1;

        var scores = new List<(FocusMode Mode, double Score)>();
        foreach (var (mode, stats) in modeStats)
        {
            var durationScore = stats.AverageDurationSeconds / maxAvg;
            var score = stats.CompletionRate * 0.6 + durationScore * 0.4;
            scores.Add((mode, score));
        }

        scores.Sort((a, b) => b.Score.CompareTo(a.Score));
        var best = scores[0];
        if (best.Score < MinConfidence)
            return null;

        if (scores.Count > 1)
        {
            var margin = best.Score - scores[1].Score;
            if (margin < MinMargin)
                return null;
        }

        return new ModeSuggestion
        {
            SuggestedMode = best.Mode,
            Confidence = best.Score,
            Reason = reasonFactory(best.Mode),
            Source = source,
            IsLocked = false
        };
    }

    private static Dictionary<FocusMode, ModeStats> BuildStats(IEnumerable<FocusSession> sessions)
    {
        var map = new Dictionary<FocusMode, ModeStats>();
        foreach (var session in sessions)
        {
            if (!map.TryGetValue(session.Mode, out var stats))
            {
                stats = new ModeStats();
                map[session.Mode] = stats;
            }

            stats.TotalSessions += 1;
            stats.TotalDurationSeconds += Math.Max(0, session.ElapsedSeconds);
            if (session.IsCompleted)
                stats.CompletedSessions += 1;
        }

        return map;
    }

    private static int HourDistance(int a, int b)
    {
        var d = Math.Abs(a - b);
        return Math.Min(d, 24 - d);
    }

    public static string ModeDisplayName(FocusMode mode) => mode switch
    {
        FocusMode.Pomodoro => "Pomodoro",
        FocusMode.Stopwatch => "Stopwatch",
        FocusMode.Flowtime => "Flowtime",
        FocusMode.TimeBlocking => "Time Blocking",
        _ => mode.ToString()
    };

    private static string EnergyDisplayName(string energy)
    {
        if (string.IsNullOrWhiteSpace(energy))
            return "These";
        var t = energy.Trim();
        return char.ToUpperInvariant(t[0]) + t[1..].ToLowerInvariant();
    }

    private sealed class ModeStats
    {
        public int TotalSessions { get; set; }
        public int CompletedSessions { get; set; }
        public double TotalDurationSeconds { get; set; }

        public double CompletionRate =>
            TotalSessions > 0 ? (double)CompletedSessions / TotalSessions : 0;

        public double AverageDurationSeconds =>
            TotalSessions > 0 ? TotalDurationSeconds / TotalSessions : 0;
    }
}
