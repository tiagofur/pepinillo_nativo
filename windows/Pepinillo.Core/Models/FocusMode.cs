namespace Pepinillo.Core.Models;

/// <summary>
/// Supported Focus Modes in Pepinillo.
/// </summary>
public enum FocusMode
{
    /// <summary>
    /// Traditional Pomodoro (25m focus, 5m break).
    /// </summary>
    Pomodoro,

    /// <summary>
    /// Open-ended stopwatch count-up session.
    /// </summary>
    Stopwatch,

    /// <summary>
    /// Flexible Flowtime method with custom break ratios.
    /// </summary>
    Flowtime,

    /// <summary>
    /// Time-blocked calendar session with fixed target end time.
    /// </summary>
    TimeBlocking
}
