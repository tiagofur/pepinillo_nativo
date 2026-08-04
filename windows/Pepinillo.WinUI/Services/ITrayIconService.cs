using System;
using Microsoft.UI.Xaml;

namespace Pepinillo.WinUI.Services;

/// <summary>
/// System tray icon and context menu (H.NotifyIcon.WinUI).
/// </summary>
public interface ITrayIconService : IDisposable
{
    /// <summary>
    /// Creates the tray icon bound to the main window lifecycle.
    /// </summary>
    void Initialize(Window mainWindow);

    /// <summary>
    /// When true, the next main-window close should terminate the process (Exit menu).
    /// </summary>
    bool IsExitRequested { get; }

    /// <summary>
    /// Request process exit (used by tray Exit and shell coordinator).
    /// </summary>
    void RequestExit();
}
