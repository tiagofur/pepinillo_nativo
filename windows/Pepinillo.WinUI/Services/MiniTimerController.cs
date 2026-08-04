using System;
using Microsoft.UI.Dispatching;
using Microsoft.UI.Windowing;
using Microsoft.UI.Xaml;
using Pepinillo.Core.Services;
using Pepinillo.Core.Utilities;
using Pepinillo.Core.ViewModels;
using Pepinillo.WinUI.Views;
using Windows.Graphics;

namespace Pepinillo.WinUI.Services;

/// <summary>
/// Creates and syncs the Compact Overlay mini timer window.
/// Restores/saves multi-monitor bounds (W14) via <see cref="ISettingsService"/>.
/// </summary>
public sealed class MiniTimerController : IMiniTimerController
{
    private readonly FocusViewModel _focusViewModel;
    private readonly ISettingsService _settingsService;
    private MiniTimerWindow? _window;
    private bool _disposed;

    public MiniTimerController(FocusViewModel focusViewModel, ISettingsService settingsService)
    {
        _focusViewModel = focusViewModel;
        _settingsService = settingsService;
    }

    public bool IsOpen => _window != null;

    public void Show()
    {
        EnsureNotDisposed();
        RunOnUi(() =>
        {
            if (_window != null)
            {
                _window.Activate();
                return;
            }

            var alwaysOnTop = true;
            try
            {
                alwaysOnTop = _settingsService.GetSettingsAsync().GetAwaiter().GetResult()
                    .CompactMiniTimerAlwaysOnTop;
            }
            catch
            {
                alwaysOnTop = true;
            }

            _window = new MiniTimerWindow(_focusViewModel, alwaysOnTop);
            _window.Closed += OnWindowClosed;

            try
            {
                TryRestorePlacement(_window);
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine($"Mini timer restore placement: {ex.Message}");
            }

            try
            {
                _window.Activate();
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine($"Mini timer activate: {ex.Message}");
            }

            // After activate the HWND exists — re-apply clamp against the real display.
            try
            {
                TryClampToVisibleDisplay(_window);
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine($"Mini timer clamp: {ex.Message}");
            }
        });
    }

    public void Hide()
    {
        EnsureNotDisposed();
        RunOnUi(() =>
        {
            if (_window == null)
                return;

            var window = _window;
            _window = null;
            window.Closed -= OnWindowClosed;
            TrySavePlacement(window);
            window.Close();
        });
    }

    public void Toggle()
    {
        if (IsOpen)
            Hide();
        else
            Show();
    }

    private void OnWindowClosed(object sender, WindowEventArgs args)
    {
        if (sender is MiniTimerWindow window)
        {
            window.Closed -= OnWindowClosed;
            TrySavePlacement(window);
        }

        _window = null;
    }

    private void TryRestorePlacement(MiniTimerWindow window)
    {
        var appWindow = window.AppWindow;
        if (appWindow == null)
            return;

        Core.Models.UserSettings settings;
        try
        {
            settings = _settingsService.GetSettingsAsync().GetAwaiter().GetResult();
        }
        catch
        {
            return;
        }

        var desired = MiniTimerPlacement.FromPersisted(
            settings.MiniTimerX,
            settings.MiniTimerY,
            settings.MiniTimerWidth,
            settings.MiniTimerHeight);

        if (desired is null)
        {
            // Still apply default size when no saved position.
            SafeResize(appWindow, MiniTimerPlacement.DefaultWidth, MiniTimerPlacement.DefaultHeight);
            return;
        }

        var rect = desired.Value;
        var work = ResolveWorkAreaForPoint(rect.X, rect.Y, appWindow);
        rect = MiniTimerPlacement.EnsureVisible(rect, work);

        SafeResize(appWindow, rect.Width, rect.Height);
        SafeMove(appWindow, rect.X, rect.Y);
    }

    private void TryClampToVisibleDisplay(MiniTimerWindow window)
    {
        var appWindow = window.AppWindow;
        if (appWindow == null)
            return;

        var pos = appWindow.Position;
        var size = appWindow.Size;
        var current = new MiniTimerPlacement.Rect(pos.X, pos.Y, size.Width, size.Height);

        DisplayArea display;
        try
        {
            display = DisplayArea.GetFromWindowId(appWindow.Id, DisplayAreaFallback.Primary);
        }
        catch
        {
            try
            {
                display = DisplayArea.GetFromPoint(new PointInt32(pos.X, pos.Y), DisplayAreaFallback.Primary);
            }
            catch
            {
                return;
            }
        }

        var workArea = display.WorkArea;
        var work = new MiniTimerPlacement.WorkArea(workArea.X, workArea.Y, workArea.Width, workArea.Height);
        if (MiniTimerPlacement.IsReasonablyOnScreen(current, work))
            return;

        var clamped = MiniTimerPlacement.ClampToWorkArea(current, work);
        SafeResize(appWindow, clamped.Width, clamped.Height);
        SafeMove(appWindow, clamped.X, clamped.Y);
    }

    private void TrySavePlacement(MiniTimerWindow window)
    {
        try
        {
            var appWindow = window.AppWindow;
            if (appWindow == null)
                return;

            var pos = appWindow.Position;
            var size = appWindow.Size;

            var settings = _settingsService.GetSettingsAsync().GetAwaiter().GetResult();
            settings.MiniTimerX = pos.X;
            settings.MiniTimerY = pos.Y;
            settings.MiniTimerWidth = size.Width > 0 ? size.Width : MiniTimerPlacement.DefaultWidth;
            settings.MiniTimerHeight = size.Height > 0 ? size.Height : MiniTimerPlacement.DefaultHeight;
            _settingsService.SaveSettingsAsync(settings).GetAwaiter().GetResult();
        }
        catch (Exception ex)
        {
            System.Diagnostics.Debug.WriteLine($"Mini timer save placement: {ex.Message}");
        }
    }

    private static MiniTimerPlacement.WorkArea ResolveWorkAreaForPoint(int x, int y, AppWindow appWindow)
    {
        try
        {
            var display = DisplayArea.GetFromPoint(new PointInt32(x, y), DisplayAreaFallback.Primary);
            var wa = display.WorkArea;
            return new MiniTimerPlacement.WorkArea(wa.X, wa.Y, wa.Width, wa.Height);
        }
        catch
        {
            try
            {
                var display = DisplayArea.GetFromWindowId(appWindow.Id, DisplayAreaFallback.Primary);
                var wa = display.WorkArea;
                return new MiniTimerPlacement.WorkArea(wa.X, wa.Y, wa.Width, wa.Height);
            }
            catch
            {
                // Fallback: large virtual desktop — EnsureVisible will no-op if work is empty.
                return new MiniTimerPlacement.WorkArea(0, 0, 1920, 1080);
            }
        }
    }

    private static void SafeMove(AppWindow appWindow, int x, int y)
    {
        try
        {
            appWindow.Move(new PointInt32(x, y));
        }
        catch (Exception ex)
        {
            System.Diagnostics.Debug.WriteLine($"Mini timer Move failed: {ex.Message}");
        }
    }

    private static void SafeResize(AppWindow appWindow, int width, int height)
    {
        try
        {
            appWindow.Resize(new SizeInt32(width, height));
        }
        catch (Exception ex)
        {
            System.Diagnostics.Debug.WriteLine($"Mini timer Resize failed: {ex.Message}");
        }
    }

    private static void RunOnUi(Action action)
    {
        var queue = DispatcherQueue.GetForCurrentThread()
            ?? App.MainWindowInstance?.DispatcherQueue;

        if (queue == null || queue.HasThreadAccess)
        {
            action();
            return;
        }

        queue.TryEnqueue(() => action());
    }

    private void EnsureNotDisposed()
    {
        if (_disposed)
            throw new ObjectDisposedException(nameof(MiniTimerController));
    }

    public void Dispose()
    {
        if (_disposed)
            return;

        _disposed = true;
        try
        {
            Hide();
        }
        catch
        {
            // Ignore dispose races on process exit.
        }
    }
}
