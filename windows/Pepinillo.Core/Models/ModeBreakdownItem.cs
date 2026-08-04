namespace Pepinillo.Core.Models;

/// <summary>
/// Aggregate focus time for a single mode within a query window.
/// </summary>
public class ModeBreakdownItem
{
    public FocusMode Mode { get; set; }
    public int TotalSeconds { get; set; }
    public int SessionCount { get; set; }

    public string ModeName => Mode.ToString();
    public int TotalMinutes => TotalSeconds / 60;
    public double FractionOfMax { get; set; }
}
