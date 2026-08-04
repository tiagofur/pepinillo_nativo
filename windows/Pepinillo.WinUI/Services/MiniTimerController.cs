using System;
using Microsoft.UI.Dispatching;
using Microsoft.UI.Xaml;
using Pepinillo.Core.Services;
using Pepinillo.Core.ViewModels;
using Pepinillo.WinUI.Views;

namespace Pepinillo.WinUI.Services;

/// <summary>
/// Creates and syncs the Compact Overlay mini timer window.
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
            _window.Activate();
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
            window.Closed -= OnWindowClosed;

        _window = null;
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
