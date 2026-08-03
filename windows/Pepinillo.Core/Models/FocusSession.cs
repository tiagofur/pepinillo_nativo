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
    /// Target target duration in seconds for timed modes.
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
}
