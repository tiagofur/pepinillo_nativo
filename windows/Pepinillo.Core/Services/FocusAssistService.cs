namespace Pepinillo.Core.Services;

/// <summary>
/// Default no-op Focus Assist implementation for non-Windows hosts and unit tests.
/// </summary>
public class FocusAssistService : IFocusAssistService
{
    public string FocusAssistStatus { get; private set; } = "Focus Assist: not available on this host";

    public void BeginFocusSession()
    {
        FocusAssistStatus = "Focus Assist: not available on this host";
    }

    public void EndFocusSession()
    {
        FocusAssistStatus = "Focus Assist: not available on this host";
    }
}
