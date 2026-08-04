namespace Pepinillo.Core.Models;

/// <summary>
/// Application and user preferences. Stored as a single SQLite row (Id = 1).
/// Schema note: column changes require a new EF migration under Pepinillo.Core/Migrations.
/// </summary>
public class UserSettings
{
    public int Id { get; set; } = 1;

    // Timer durations (minutes)
    public int PomodoroFocusMinutes { get; set; } = 25;
    public int ShortBreakMinutes { get; set; } = 5;
    public int LongBreakMinutes { get; set; } = 15;
    public int LongBreakInterval { get; set; } = 4;
    public int FlowtimeTargetMinutes { get; set; } = 30;
    public int TimeBlockingMinutes { get; set; } = 60;

    // Automation & behavior
    public bool AutoStartBreaks { get; set; }
    public bool AutoStartFocusSessions { get; set; }
    public bool EnableWindowsDoNotDisturbSync { get; set; } = true;
    public bool MinimizeToSystemTrayOnClose { get; set; } = true;
    /// <summary>When true, register to launch Pepinillo at Windows sign-in (StartupTask or Run key).</summary>
    public bool LaunchAtWindowsStartup { get; set; }

    // Notifications & audio
    public bool EnableToastNotifications { get; set; } = true;
    public bool EnableTickingSound { get; set; }
    public double TickingVolume { get; set; } = 0.5;
    public bool EnableSoundscapes { get; set; } = true;
    public double SoundscapesMasterVolume { get; set; } = 0.7;

    // Visual
    /// <summary>System, Dark, Light, Forest, Ocean, Sunset, OLEDBlack</summary>
    public string SelectedTheme { get; set; } = "System";
    public bool UseMicaBackdrop { get; set; } = true;
    public bool CompactMiniTimerAlwaysOnTop { get; set; } = true;

    // Global hotkeys (rebindable in Settings; see HotkeyChordParser)
    public string PlayPauseHotkey { get; set; } = "Win+Shift+P";
    public string SkipHotkey { get; set; } = "Win+Shift+S";
    public string MiniTimerHotkey { get; set; } = "Win+Shift+M";

    /// <summary>UI language preference: en, es, pt (BCP-47 short tags).</summary>
    public string PreferredLanguage { get; set; } = "en";
}
