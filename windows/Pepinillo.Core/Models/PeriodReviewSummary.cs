namespace Pepinillo.Core.Models;

/// <summary>
/// Weekly or monthly focus review comparing the current period to the previous one (UTC).
/// Weeks use Monday-start (ISO-like) UTC weeks; months use calendar months in UTC.
/// </summary>
public sealed class PeriodReviewSummary
{
    /// <summary>e.g. "This week" or "This month".</summary>
    public string Label { get; set; } = string.Empty;

    /// <summary>e.g. "Previous week" label for secondary stats.</summary>
    public string PreviousLabel { get; set; } = string.Empty;

    /// <summary>Inclusive start of the current period (UTC date).</summary>
    public DateTime PeriodStartUtc { get; set; }

    /// <summary>Exclusive end of the current period (UTC date).</summary>
    public DateTime PeriodEndExclusiveUtc { get; set; }

    public double FocusHours { get; set; }

    public int SessionCount { get; set; }

    /// <summary>Top mode by total focus seconds; empty when no sessions.</summary>
    public string TopModeName { get; set; } = string.Empty;

    public double PreviousFocusHours { get; set; }

    public int PreviousSessionCount { get; set; }

    public string PreviousTopModeName { get; set; } = string.Empty;

    /// <summary>
    /// Focus-hours trend vs previous period: 1 = up, 0 = flat, -1 = down.
    /// </summary>
    public int TrendVsPrevious { get; set; }

    /// <summary>Current streak (UTC days) at load time — useful hero context on weekly card.</summary>
    public int CurrentStreakDays { get; set; }

    /// <summary>When true, UI should show paywall teaser instead of detail numbers.</summary>
    public bool IsLocked { get; set; }

    public string TeaserMessage { get; set; } = string.Empty;
}
