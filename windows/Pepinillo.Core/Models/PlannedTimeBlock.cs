using System;

namespace Pepinillo.Core.Models;

/// <summary>
/// Planned desktop calendar time block (W13). Local SQLite only — no external calendar sync.
/// </summary>
public class PlannedTimeBlock
{
    public Guid Id { get; set; } = Guid.NewGuid();

    /// <summary>Block start instant in UTC.</summary>
    public DateTime StartAtUtc { get; set; }

    public int DurationMinutes { get; set; } = 60;

    public string Title { get; set; } = "Time Block";

    /// <summary>Optional link to a <see cref="TaskItem"/>.</summary>
    public Guid? TaskItemId { get; set; }

    public bool IsCompleted { get; set; }

    public DateTime CreatedAtUtc { get; set; } = DateTime.UtcNow;
}
