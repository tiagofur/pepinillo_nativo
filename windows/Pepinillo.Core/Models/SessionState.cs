namespace Pepinillo.Core.Models;

/// <summary>
/// Execution state of a focus session.
/// </summary>
public enum SessionState
{
    /// <summary>
    /// Timer is stopped or ready to start.
    /// </summary>
    Idle,

    /// <summary>
    /// Active focus session in progress.
    /// </summary>
    Running,

    /// <summary>
    /// Focus session is currently paused.
    /// </summary>
    Paused,

    /// <summary>
    /// Active break timer after focus completed.
    /// </summary>
    Break,

    /// <summary>
    /// Session finished successfully.
    /// </summary>
    Completed
}
