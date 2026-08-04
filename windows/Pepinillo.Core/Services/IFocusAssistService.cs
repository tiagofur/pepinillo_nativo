namespace Pepinillo.Core.Services;

/// <summary>
/// Best-effort OS Do Not Disturb / Focus Assist integration.
/// Platform implementations may no-op when the OS API is unavailable.
/// </summary>
public interface IFocusAssistService
{
    /// <summary>Called when a focus (work) session starts running.</summary>
    void BeginFocusSession();

    /// <summary>Called when the session returns to idle/completed or is stopped.</summary>
    void EndFocusSession();
}
