namespace Pepinillo.Core.Services;

/// <summary>
/// Default no-op Focus Assist implementation for non-Windows hosts and unit tests.
/// </summary>
public class FocusAssistService : IFocusAssistService
{
    public void BeginFocusSession()
    {
        // OS integration is provided by the WinUI host.
    }

    public void EndFocusSession()
    {
        // OS integration is provided by the WinUI host.
    }
}
