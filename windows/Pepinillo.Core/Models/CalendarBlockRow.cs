using System;

namespace Pepinillo.Core.Models;

/// <summary>
/// UI row for a planned time block (display labels computed by the calendar ViewModel).
/// </summary>
public sealed class CalendarBlockRow
{
    public Guid Id { get; init; }

    public DateTime StartAtUtc { get; init; }

    public int DurationMinutes { get; init; }

    public string Title { get; init; } = "Time Block";

    public Guid? TaskItemId { get; init; }

    public bool IsCompleted { get; init; }

    /// <summary>Local time range e.g. "09:00 – 10:00".</summary>
    public string TimeRangeLabel { get; set; } = string.Empty;

    /// <summary>Optional linked task title for the card subtitle.</summary>
    public string TaskTitle { get; set; } = string.Empty;

    public bool HasTask => TaskItemId.HasValue && !string.IsNullOrWhiteSpace(TaskTitle);

    public string DurationLabel { get; set; } = string.Empty;
}
