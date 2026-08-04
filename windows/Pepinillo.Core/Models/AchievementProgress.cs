namespace Pepinillo.Core.Models;

/// <summary>
/// Progress toward a local FREE achievement computed from completed focus sessions.
/// </summary>
public sealed class AchievementProgress
{
    public string Id { get; set; } = string.Empty;

    public string Title { get; set; } = string.Empty;

    public string Description { get; set; } = string.Empty;

    public bool IsUnlocked { get; set; }

    public int ProgressCurrent { get; set; }

    public int ProgressTarget { get; set; }

    /// <summary>0–1 ratio of current/target (clamped).</summary>
    public double ProgressRatio =>
        ProgressTarget <= 0
            ? 0
            : Math.Clamp((double)ProgressCurrent / ProgressTarget, 0, 1);

    /// <summary>UI badge: check when unlocked, lock when still in progress (avoids bool→Visibility x:Bind).</summary>
    public string StatusGlyph => IsUnlocked ? "✓" : "🔒";
}
