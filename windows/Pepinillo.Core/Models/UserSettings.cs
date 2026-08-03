namespace Pepinillo.Core.Models;

/// <summary>
/// Comprehensive application and user settings for Pepinillo Windows.
/// </summary>
public class UserSettings
{
    // Timer Durations (in minutes)
    public int PomodoroFocusMinutes { get; set; } = 25;
    public int ShortBreakMinutes { get; set; } = 5;
    public int LongBreakMinutes { get; set; } = 15;
    public int LongBreakInterval { get; set; } = 4;
    public int FlowtimeTargetMinutes { get; set; } = 30;

    // Automation & Behavior
    public bool AutoStartBreaks { get; set; } = false;
    public bool AutoStartFocusSessions { get; set; } = false;
    public bool EnableWindowsDoNotDisturbSync { get; set; } = true;
    public bool MinimizeToSystemTrayOnClose { get; set; } = true;

    // Notifications & Audio
    public bool EnableToastNotifications { get; set; } = true;
    public bool EnableTickingSound { get; set; } = false;
    public double TickingVolume { get; set; } = 0.5;
    public bool EnableSoundscapes { get; set; } = true;
    public double SoundscapesMasterVolume { get; set; } = 0.7;

    // Visual Customization & Themes
    public string SelectedTheme { get; set; } = "System"; // System, Dark, Light, Forest, Ocean, Sunset, OLEDBlack
    public bool UseMicaBackdrop { get; set; } = true;
    public bool CompactMiniTimerAlwaysOnTop { get; set; } = true;

    // Hotkeys
    public string PlayPauseHotkey { get; set; } = "Win+Shift+P";
    public string SkipHotkey { get; set; } = "Win+Shift+S";
    public string MiniTimerHotkey { get; set; } = "Win+Shift+M";
}
