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
    /// <summary>When true, preferred soundscape auto-plays when a focus work phase starts.</summary>
    public bool AutoPlaySoundscapeOnFocus { get; set; } = true;
    /// <summary>Catalog track id used for auto-play and last manual selection (default rain).</summary>
    public string? PreferredSoundscapeId { get; set; } = "rain";

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

    /// <summary>
    /// Stable per-install device id sent as <c>X-Device-ID</c> on authenticated API calls.
    /// </summary>
    public string? DeviceId { get; set; }

    /// <summary>UTC timestamp of last successful cloud session sync (for lastSyncAt).</summary>
    public DateTime? LastSyncAtUtc { get; set; }

    /// <summary>
    /// ISO week Monday (UTC) for which <see cref="StreakProtectionUsesThisWeek"/> applies.
    /// Pepinillo+ / Everywhere: 1 streak skip per week.
    /// </summary>
    public DateTime? StreakProtectionWeekStartUtc { get; set; }

    /// <summary>Number of streak-protection skips consumed in the current ISO week (max 1).</summary>
    public int StreakProtectionUsesThisWeek { get; set; }
}
