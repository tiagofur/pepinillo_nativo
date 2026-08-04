using System;
using System.Diagnostics;
using Pepinillo.Core.Services;

namespace Pepinillo.WinUI.Services;

/// <summary>
/// Best-effort Windows Focus Assist / quiet hours bridge.
/// <para>
/// Windows does not expose a stable public API for third-party apps to toggle Focus Assist.
/// This implementation tracks session intent, exposes an honest <see cref="FocusAssistStatus"/>,
/// and never reports fake "DND enabled" success.
/// </para>
/// </summary>
public sealed class WindowsFocusAssistService : IFocusAssistService
{
    private bool _sessionActive;

    /// <inheritdoc />
    public string FocusAssistStatus { get; private set; } =
        "Focus Assist: idle (OS toggle not available to third-party apps)";

    public void BeginFocusSession()
    {
        if (_sessionActive)
            return;

        _sessionActive = true;

        try
        {
            // Reserved: when Microsoft ships a public Focus Session / Quiet Hours API for
            // Win32/WASDK apps, call it here. Until then we only record intent.
            // Do NOT open ms-settings:quiethours automatically — noisy and not real sync.
            FocusAssistStatus =
                "Focus Assist: intent recorded (OS toggle not available to third-party apps)";
            Debug.WriteLine($"[FocusAssist] BeginFocusSession — {FocusAssistStatus}");
        }
        catch (Exception ex)
        {
            FocusAssistStatus = $"Focus Assist: begin failed ({ex.Message})";
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
            FocusAssistStatus =
                "Focus Assist: session ended (OS was not modified by Pepinillo)";
            Debug.WriteLine($"[FocusAssist] EndFocusSession — {FocusAssistStatus}");
        }
        catch (Exception ex)
        {
            FocusAssistStatus = $"Focus Assist: end failed ({ex.Message})";
            Debug.WriteLine($"[FocusAssist] End failed: {ex.Message}");
        }
    }
}
