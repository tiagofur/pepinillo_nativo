namespace Pepinillo.Core.Models;

/// <summary>
/// Display row for the day planner hour column (local hour 0–23).
/// </summary>
public sealed class CalendarHourSlot
{
    public int HourLocal { get; init; }

    public string HourLabel { get; init; } = string.Empty;

    public string AddButtonLabel { get; set; } = "Add";

    public string AutomationName { get; set; } = string.Empty;
}
