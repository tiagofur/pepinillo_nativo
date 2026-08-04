using System;
using System.Collections.Generic;

namespace Pepinillo.Core.Models;

/// <summary>
/// Task domain model representing a planned task or subtask.
/// </summary>
public class TaskItem
{
    public Guid Id { get; set; } = Guid.NewGuid();

    public string Title { get; set; } = string.Empty;

    public string? Description { get; set; }

    public int EstimatedMinutes { get; set; } = 25;

    public int CompletedMinutes { get; set; }

    /// <summary>
    /// Priority 0 (none/low) … 3 (urgent).
    /// </summary>
    public int Priority { get; set; }

    /// <summary>
    /// Energy bucket: deep | shallow | admin (empty = unset).
    /// </summary>
    public string EnergyLevel { get; set; } = string.Empty;

    /// <summary>
    /// Estimated pomodoro count (alternative to minutes).
    /// </summary>
    public int EstimatedPomodoros { get; set; }

    /// <summary>
    /// Completed pomodoro count attributed to this task.
    /// </summary>
    public int CompletedPomodoros { get; set; }

    public bool IsCompleted { get; set; }

    public DateTime? DueDate { get; set; }

    public Guid? ParentTaskId { get; set; }

    public List<TaskItem> SubTasks { get; set; } = new();

    /// <summary>
    /// Simplified recurrence: empty/None, FREQ=DAILY, FREQ=WEEKLY.
    /// </summary>
    public string? RecurrenceRule { get; set; }

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    public bool IsSynced { get; set; }

    /// <summary>True when priority badge should show (WinUI Visibility cannot bind to int).</summary>
    public bool HasPriority => Priority is >= 1 and <= 3;

    /// <summary>True when energy badge should show.</summary>
    public bool HasEnergy => !string.IsNullOrWhiteSpace(EnergyLevel);

    /// <summary>Display helper for priority badge.</summary>
    public string PriorityLabel => Priority switch
    {
        3 => "P3",
        2 => "P2",
        1 => "P1",
        _ => string.Empty
    };

    /// <summary>Display helper for energy badge.</summary>
    public string EnergyLabel => string.IsNullOrWhiteSpace(EnergyLevel)
        ? string.Empty
        : char.ToUpperInvariant(EnergyLevel[0]) + EnergyLevel[1..].ToLowerInvariant();

    /// <summary>Compact estimate chip text (e.g. "25m").</summary>
    public string EstimateChipLabel => EstimatedMinutes > 0 ? $"{EstimatedMinutes}m" : string.Empty;

    /// <summary>True when estimate chip should show.</summary>
    public bool HasEstimate => EstimatedMinutes > 0;
}
