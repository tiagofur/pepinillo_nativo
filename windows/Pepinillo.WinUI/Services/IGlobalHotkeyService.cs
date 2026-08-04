using System;
using Microsoft.UI.Xaml;

namespace Pepinillo.WinUI.Services;

/// <summary>
/// Registers process-wide hotkeys via Win32 RegisterHotKey for background control.
/// </summary>
public interface IGlobalHotkeyService : IDisposable
{
    /// <summary>
    /// Attach message subclassing and register hotkeys against the main window HWND.
    /// </summary>
    void Initialize(Window mainWindow);

    /// <summary>
    /// Re-read settings strings and re-register (defaults used when parse fails).
    /// </summary>
    void RefreshFromSettings();
}
