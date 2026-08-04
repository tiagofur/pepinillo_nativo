using System;
using System.Diagnostics;
using Pepinillo.Core.Services;

namespace Pepinillo.WinUI.Services;

/// <summary>
/// Best-effort Windows Focus Assist / quiet hours bridge.
/// <para>
/// Windows does not expose a stable public API for third-party apps to toggle Focus Assist.
/// This implementation tracks session intent and silently no-ops when OS hooks are unavailable.
/// It never reports fake success to the user.
/// </para>
/// </summary>
public sealed class WindowsFocusAssistService : IFocusAssistService
{
    private bool _sessionActive;

    public void BeginFocusSession()
    {
        if (_sessionActive)
            return;

        _sessionActive = true;

        try
        {
            // Reserved: future Focus Sessions / quiet-hours public APIs.
            // Do not open Settings UI automatically — that is noisy and not a real sync.
            Debug.WriteLine("[FocusAssist] BeginFocusSession (best-effort no-op if OS API unavailable)");
        }
        catch (Exception ex)
        {
            Debug.WriteLine($"[FocusAssist] Begin failed: {ex.Message}");
        }
    }

    public void EndFocusSession()
    {
        if (!_sessionActive)
            return;

        _sessionActive = false;

        try
        {
            Debug.WriteLine("[FocusAssist] EndFocusSession (best-effort no-op if OS API unavailable)");
        }
        catch (Exception ex)
        {
            Debug.WriteLine($"[FocusAssist] End failed: {ex.Message}");
        }
    }
}
