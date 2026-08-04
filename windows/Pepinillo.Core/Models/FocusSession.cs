using System;

namespace Pepinillo.Core.Models;

/// <summary>
/// Represents an individual deep work focus session.
/// </summary>
public class FocusSession
{
    public Guid Id { get; set; } = Guid.NewGuid();

    public FocusMode Mode { get; set; } = FocusMode.Pomodoro;

    /// <summary>
    /// Target duration in seconds for timed modes.
    /// </summary>
    public int TargetDurationSeconds { get; set; } = 1500; // 25 min default

    /// <summary>
    /// Actual elapsed seconds focused.
    /// </summary>
    public int ElapsedSeconds { get; set; }

    /// <summary>
    /// Optional linked Task ID.
    /// </summary>
    public Guid? TaskItemId { get; set; }

    public DateTime StartedAt { get; set; } = DateTime.UtcNow;

    public DateTime? CompletedAt { get; set; }

    public bool IsCompleted { get; set; }

    public bool IsSynced { get; set; }

    /// <summary>
    /// Optional post-session journal note (reflection).
    /// </summary>
    public string? JournalNote { get; set; }

    /// <summary>
    /// Optional energy/feeling rating after the session (1–5).
    /// </summary>
    public int? EnergyRating { get; set; }
}
