using System;
using System.Threading.Tasks;

namespace Pepinillo.Core.Services;

/// <summary>
/// Pepinillo+ / Everywhere: one streak skip per ISO week (UTC Monday–Sunday).
/// Free users never bridge gaps.
/// </summary>
public interface IStreakProtectionService
{
    /// <summary>ISO week Monday 00:00 UTC containing <paramref name="utcNow"/>.</summary>
    DateTime GetIsoWeekStartUtc(DateTime utcNow);

    /// <summary>
    /// Premium and fewer than one skip already consumed this ISO week.
    /// </summary>
    Task<bool> CanUseSkipAsync(DateTime utcNow);

    /// <summary>
    /// Consumes one skip for the ISO week of <paramref name="utcNow"/> when available.
    /// Returns true when a skip was newly consumed.
    /// </summary>
    Task<bool> TryConsumeSkipAsync(DateTime utcNow);

    /// <summary>
    /// Whether premium may bridge a missing day on <paramref name="gapDayUtc"/>.
    /// Per-week multiplicity is enforced by the streak walk; this gates free vs paid.
    /// </summary>
    Task<bool> CanBridgeGapThisWeekAsync(DateTime gapDayUtc, DateTime evaluationTodayUtc);

    /// <summary>
    /// Marks a skip used for the evaluation week's ISO week when the gap falls in that week.
    /// Auto-called when bridging a gap during streak calculation.
    /// </summary>
    Task<bool> EnsureBridgedAndConsumeAsync(DateTime gapDayUtc, DateTime evaluationTodayUtc);

    /// <summary>Human-readable status for Analytics UI.</summary>
    Task<StreakProtectionStatus> GetStatusAsync(DateTime utcNow);
}

public sealed class StreakProtectionStatus
{
    public bool IsPremium { get; init; }
    public bool Available { get; init; }
    public bool UsedThisWeek { get; init; }
    public string Caption { get; init; } = string.Empty;
}
