using System;
using System.Runtime.InteropServices;
using Microsoft.UI.Dispatching;
using Microsoft.UI.Xaml;
using Pepinillo.Core.Services;
using Pepinillo.Core.Utilities;
using Pepinillo.Core.ViewModels;
using WinRT.Interop;

namespace Pepinillo.WinUI.Services;

/// <summary>
/// Global hotkeys via Win32 <c>RegisterHotKey</c> + window subclass for <c>WM_HOTKEY</c>.
/// <para>
/// Defaults: Win+Shift+P play/pause, Win+Shift+S skip break, Win+Shift+M toggle mini timer.
/// Registration can fail if another process already owns the combination (e.g. PowerToys).
/// Conflicts are ignored for that slot — remaining hotkeys still register.
/// </para>
/// </summary>
public sealed class GlobalHotkeyService : IGlobalHotkeyService
{
    private readonly FocusViewModel _focusViewModel;
    private readonly ISettingsService _settingsService;
    private readonly IMiniTimerController _miniTimerController;
    private readonly NativeMethods.SubclassProc _subclassProc;

    private IntPtr _hwnd = IntPtr.Zero;
    private DispatcherQueue? _dispatcher;
    private bool _subclassInstalled;
    private bool _disposed;

    public GlobalHotkeyService(
        FocusViewModel focusViewModel,
        ISettingsService settingsService,
        IMiniTimerController miniTimerController)
    {
        _focusViewModel = focusViewModel;
        _settingsService = settingsService;
        _miniTimerController = miniTimerController;
        // Keep delegate alive for native callback lifetime.
        _subclassProc = SubclassWndProc;
    }

    public void Initialize(Window mainWindow)
    {
        ObjectDisposedException.ThrowIf(_disposed, this);

        _dispatcher = mainWindow.DispatcherQueue;
        _hwnd = WindowNative.GetWindowHandle(mainWindow);
        if (_hwnd == IntPtr.Zero)
            return;

        if (!_subclassInstalled)
        {
            if (NativeMethods.SetWindowSubclass(_hwnd, _subclassProc, NativeMethods.SubclassId, 0))
                _subclassInstalled = true;
        }

        RefreshFromSettings();
    }

    public void RefreshFromSettings()
    {
        if (_hwnd == IntPtr.Zero)
            return;

        UnregisterAll();

        var play = (NativeMethods.MOD_WIN | NativeMethods.MOD_SHIFT | NativeMethods.MOD_NOREPEAT, NativeMethods.VK_P);
        var skip = (NativeMethods.MOD_WIN | NativeMethods.MOD_SHIFT | NativeMethods.MOD_NOREPEAT, NativeMethods.VK_S);
        var mini = (NativeMethods.MOD_WIN | NativeMethods.MOD_SHIFT | NativeMethods.MOD_NOREPEAT, NativeMethods.VK_M);

        try
        {
            var settings = _settingsService.GetSettingsAsync().GetAwaiter().GetResult();
            play = ParseHotkeyOrDefault(settings.PlayPauseHotkey, play);
            skip = ParseHotkeyOrDefault(settings.SkipHotkey, skip);
            mini = ParseHotkeyOrDefault(settings.MiniTimerHotkey, mini);
        }
        catch
        {
            // Keep fixed defaults.
        }

        // Ignore individual RegisterHotKey failures (conflict with other apps).
        _ = NativeMethods.RegisterHotKey(_hwnd, NativeMethods.HotkeyIdPlayPause, play.Item1, play.Item2);
        _ = NativeMethods.RegisterHotKey(_hwnd, NativeMethods.HotkeyIdSkip, skip.Item1, skip.Item2);
        _ = NativeMethods.RegisterHotKey(_hwnd, NativeMethods.HotkeyIdMiniTimer, mini.Item1, mini.Item2);
    }

    private nint SubclassWndProc(
        IntPtr hWnd,
        uint uMsg,
        nint wParam,
        nint lParam,
        nuint uIdSubclass,
        nuint dwRefData)
    {
        if (uMsg == NativeMethods.WM_HOTKEY)
        {
            var id = wParam.ToInt32();
            MarshalToUi(() => HandleHotkey(id));
            return 0;
        }

        return NativeMethods.DefSubclassProc(hWnd, uMsg, wParam, lParam);
    }

    private void HandleHotkey(int id)
    {
        switch (id)
        {
            case NativeMethods.HotkeyIdPlayPause:
                _focusViewModel.TogglePlayPause();
                break;
            case NativeMethods.HotkeyIdSkip:
                _focusViewModel.SkipOrAdvance();
                break;
            case NativeMethods.HotkeyIdMiniTimer:
                _miniTimerController.Toggle();
                break;
        }
    }

    private void MarshalToUi(Action action)
    {
        var queue = _dispatcher ?? DispatcherQueue.GetForCurrentThread();
        if (queue == null || queue.HasThreadAccess)
        {
            action();
            return;
        }

        queue.TryEnqueue(() => action());
    }

    /// <summary>
    /// Maps a settings chord string to Win32 modifiers + VK via <see cref="HotkeyChordParser"/>.
    /// Falls back to <paramref name="fallback"/> on failure.
    /// </summary>
    internal static (uint modifiers, uint vk) ParseHotkeyOrDefault(
        string? text,
        (uint modifiers, uint vk) fallback)
    {
        if (!HotkeyChordParser.TryParse(text, out var chord))
            return fallback;

        uint mods = NativeMethods.MOD_NOREPEAT;
        if (chord.Win) mods |= NativeMethods.MOD_WIN;
        if (chord.Shift) mods |= NativeMethods.MOD_SHIFT;
        if (chord.Ctrl) mods |= NativeMethods.MOD_CONTROL;
        if (chord.Alt) mods |= NativeMethods.MOD_ALT;

        return (mods, chord.Key);
    }

    private void UnregisterAll()
    {
        if (_hwnd == IntPtr.Zero)
            return;

        NativeMethods.UnregisterHotKey(_hwnd, NativeMethods.HotkeyIdPlayPause);
        NativeMethods.UnregisterHotKey(_hwnd, NativeMethods.HotkeyIdSkip);
        NativeMethods.UnregisterHotKey(_hwnd, NativeMethods.HotkeyIdMiniTimer);
    }

    public void Dispose()
    {
        if (_disposed)
            return;

        _disposed = true;
        UnregisterAll();

        if (_subclassInstalled && _hwnd != IntPtr.Zero)
        {
            NativeMethods.RemoveWindowSubclass(_hwnd, _subclassProc, NativeMethods.SubclassId);
            _subclassInstalled = false;
        }

        _hwnd = IntPtr.Zero;
    }
}
