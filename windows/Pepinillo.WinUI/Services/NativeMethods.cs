using System;
using System.Runtime.InteropServices;

namespace Pepinillo.WinUI.Services;

/// <summary>
/// Win32 P/Invoke surface for global hotkeys and window subclassing.
/// </summary>
internal static class NativeMethods
{
    public const int WM_HOTKEY = 0x0312;

    public const uint MOD_ALT = 0x0001;
    public const uint MOD_CONTROL = 0x0002;
    public const uint MOD_SHIFT = 0x0004;
    public const uint MOD_WIN = 0x0008;
    public const uint MOD_NOREPEAT = 0x4000;

    public const uint VK_P = 0x50;
    public const uint VK_S = 0x53;
    public const uint VK_M = 0x4D;

    public const int HotkeyIdPlayPause = 0x1001;
    public const int HotkeyIdSkip = 0x1002;
    public const int HotkeyIdMiniTimer = 0x1003;

    public const nuint SubclassId = 0x50455049; // 'PEPI'

    [DllImport("user32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool RegisterHotKey(IntPtr hWnd, int id, uint fsModifiers, uint vk);

    [DllImport("user32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool UnregisterHotKey(IntPtr hWnd, int id);

    [DllImport("comctl32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool SetWindowSubclass(
        IntPtr hWnd,
        SubclassProc pfnSubclass,
        nuint uIdSubclass,
        nuint dwRefData);

    [DllImport("comctl32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool RemoveWindowSubclass(
        IntPtr hWnd,
        SubclassProc pfnSubclass,
        nuint uIdSubclass);

    [DllImport("comctl32.dll")]
    public static extern nint DefSubclassProc(IntPtr hWnd, uint uMsg, nint wParam, nint lParam);

    public delegate nint SubclassProc(
        IntPtr hWnd,
        uint uMsg,
        nint wParam,
        nint lParam,
        nuint uIdSubclass,
        nuint dwRefData);
}
