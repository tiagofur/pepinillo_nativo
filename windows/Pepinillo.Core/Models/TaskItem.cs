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

    public bool IsCompleted { get; set; }

    public DateTime? DueDate { get; set; }

    public Guid? ParentTaskId { get; set; }

    public List<TaskItem> SubTasks { get; set; } = new();

    public string? RecurrenceRule { get; set; }

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    public bool IsSynced { get; set; }
}
