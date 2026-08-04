namespace Pepinillo.Core.Services;

/// <summary>
/// Best-effort OS Do Not Disturb / Focus Assist integration.
/// Platform implementations may no-op when the OS API is unavailable.
/// Never report fake success — expose honest <see cref="FocusAssistStatus"/> instead.
/// </summary>
public interface IFocusAssistService
{
    /// <summary>Called when a focus (work) session starts running.</summary>
    void BeginFocusSession();

    /// <summary>Called when the session returns to idle/completed or is stopped.</summary>
    void EndFocusSession();

    /// <summary>
    /// Human-readable diagnostic status for Settings (never claims DND is on unless verified).
    /// </summary>
    string FocusAssistStatus { get; }
}
