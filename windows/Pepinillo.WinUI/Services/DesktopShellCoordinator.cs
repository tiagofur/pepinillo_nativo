using System;
using H.NotifyIcon;
using Microsoft.UI.Windowing;
using Microsoft.UI.Xaml;
using Pepinillo.Core.Services;
using WinRT.Interop;

namespace Pepinillo.WinUI.Services;

/// <summary>
/// Wires tray, global hotkeys, and minimize-to-tray close behavior after MainWindow exists.
/// </summary>
public sealed class DesktopShellCoordinator : IDisposable
{
    private readonly ITrayIconService _trayIconService;
    private readonly IGlobalHotkeyService _globalHotkeyService;
    private readonly ISettingsService _settingsService;
    private readonly IMiniTimerController _miniTimerController;

    private Window? _mainWindow;
    private AppWindow? _appWindow;
    private bool _disposed;

    public DesktopShellCoordinator(
        ITrayIconService trayIconService,
        IGlobalHotkeyService globalHotkeyService,
        ISettingsService settingsService,
        IMiniTimerController miniTimerController)
    {
        _trayIconService = trayIconService;
        _globalHotkeyService = globalHotkeyService;
        _settingsService = settingsService;
        _miniTimerController = miniTimerController;
    }

    public void Attach(Window mainWindow)
    {
        ObjectDisposedException.ThrowIf(_disposed, this);

        _mainWindow = mainWindow;

        var hwnd = WindowNative.GetWindowHandle(mainWindow);
        var windowId = Microsoft.UI.Win32Interop.GetWindowIdFromWindow(hwnd);
        _appWindow = AppWindow.GetFromWindowId(windowId);
        _appWindow.Closing += OnAppWindowClosing;

        _trayIconService.Initialize(mainWindow);
        _globalHotkeyService.Initialize(mainWindow);
    }

    private async void OnAppWindowClosing(AppWindow sender, AppWindowClosingEventArgs args)
    {
        if (_trayIconService.IsExitRequested || _disposed)
            return;

        try
        {
            var settings = await _settingsService.GetSettingsAsync();
            if (!settings.MinimizeToSystemTrayOnClose)
                return;

            args.Cancel = true;

            if (_mainWindow != null)
            {
                try
                {
                    WindowExtensions.Hide(_mainWindow, enableEfficiencyMode: true);
                    return;
                }
                catch
                {
                    // Fall through to AppWindow.Hide.
                }
            }

            sender.Hide();
        }
        catch
        {
            // If settings fail, allow normal close.
        }
    }

    public void Dispose()
    {
        if (_disposed)
            return;

        _disposed = true;

        if (_appWindow != null)
            _appWindow.Closing -= OnAppWindowClosing;

        _globalHotkeyService.Dispose();
        _trayIconService.Dispose();
        _miniTimerController.Dispose();

        _appWindow = null;
        _mainWindow = null;
    }
}
