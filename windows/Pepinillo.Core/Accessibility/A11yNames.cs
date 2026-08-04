namespace Pepinillo.Core.Accessibility;

/// <summary>
/// Stable English automation names for WinUI <c>AutomationProperties.Name</c>.
/// Narrator language follows the OS; keep these English for Store/a11y smoke consistency.
/// XAML literals should match these constants.
/// </summary>
public static class A11yNames
{
    // ── Focus ──────────────────────────────────────────────────────────────
    public const string FocusModePomodoro = "Select Pomodoro mode";
    public const string FocusModeStopwatch = "Select Stopwatch mode";
    public const string FocusModeFlowtime = "Select Flowtime mode";
    public const string FocusModeTimeBlock = "Select Time Block mode";
    public const string FocusStart = "Start or resume focus session";
    public const string FocusPause = "Pause focus session";
    public const string FocusStop = "Stop focus session";
    public const string FocusSkip = "Skip break";
    public const string FocusMiniTimer = "Toggle mini timer window";
    public const string FocusTaskCombo = "Link focus session to task";
    public const string FocusClearTask = "Clear linked task";
    public const string FocusJournalNotes = "Session journal notes";
    public const string FocusJournalEnergy = "Session energy rating 1 to 5";
    public const string FocusJournalSave = "Save session journal";
    public const string FocusJournalDismiss = "Dismiss session journal";
    public const string FocusTimerDisplay = "Session timer";
    public const string FocusProgress = "Session progress";

    // ── Tasks ──────────────────────────────────────────────────────────────
    public const string TasksNewTitle = "New task title";
    public const string TasksEstimate = "Estimated minutes for new task";
    public const string TasksAdd = "Add task";
    public const string TasksPriority = "New task priority";
    public const string TasksEnergy = "New task energy";
    public const string TasksRecurrence = "New task recurrence";
    public const string TasksFilterToday = "Filter tasks Today";
    public const string TasksFilterUpcoming = "Filter tasks Upcoming";
    public const string TasksFilterInbox = "Filter tasks Inbox";
    public const string TasksFilterAll = "Filter tasks All";
    public const string TasksComplete = "Complete task";
    public const string TasksDelete = "Delete task";
    public const string TasksAddSubtask = "Add subtask";
    public const string TasksEmptyCta = "Add your first task";
    public const string TasksSubtaskTitle = "Subtask title";

    // ── Paywall ────────────────────────────────────────────────────────────
    public const string PaywallBuyPlus = "Buy Pepinillo Plus";
    public const string PaywallSubscribeMonthly = "Subscribe monthly Everywhere";
    public const string PaywallSubscribeAnnual = "Subscribe annual Everywhere";
    public const string PaywallRestore = "Restore purchases";
    public const string PaywallManageStore = "Manage subscriptions in Microsoft Store";

    // ── Settings ───────────────────────────────────────────────────────────
    public const string SettingsSave = "Save settings";
    public const string SettingsResetHotkeys = "Reset hotkeys to defaults";
    public const string SettingsPlayPauseHotkey = "Play pause global hotkey";
    public const string SettingsSkipHotkey = "Skip break global hotkey";
    public const string SettingsMiniTimerHotkey = "Mini timer global hotkey";
    public const string SettingsUpgrade = "Upgrade plan";
    public const string SettingsPrivacy = "Privacy policy";
    public const string SettingsTerms = "Terms of use";

    // ── Analytics ──────────────────────────────────────────────────────────
    public const string AnalyticsExportCsv = "Export focus history as CSV";
    public const string AnalyticsExportPdf = "Export focus history as PDF";
    public const string AnalyticsWeeklyUpgrade = "Upgrade for Weekly Review";
    public const string AnalyticsMonthlyUpgrade = "Upgrade for Monthly Review";
    public const string AnalyticsAchievements = "Achievements list";

    // ── Account ────────────────────────────────────────────────────────────
    public const string AccountEmail = "Account email";
    public const string AccountPassword = "Account password";
    public const string AccountDisplayName = "Display name";
    public const string AccountSignIn = "Sign in";
    public const string AccountRegister = "Register account";
    public const string AccountSignOut = "Sign out";
    public const string AccountSync = "Sync now";

    // ── Soundscapes ────────────────────────────────────────────────────────
    public const string SoundscapesVolume = "Master volume";
    public const string SoundscapesStopAll = "Stop all soundscapes";
    public const string SoundscapesPlayTrack = "Play soundscape track";
    public const string SoundscapesStopTrack = "Stop soundscape track";

    // ── Mini timer / shell ─────────────────────────────────────────────────
    public const string MiniTimerElapsed = "Mini timer elapsed";
    public const string MiniTimerPlayPause = "Start or pause from mini timer";
    public const string MiniTimerStop = "Stop from mini timer";
    public const string NavFocus = "Navigate to Focus";
    public const string NavTasks = "Navigate to Tasks";
    public const string NavAnalytics = "Navigate to Analytics";
    public const string NavSoundscapes = "Navigate to Soundscapes";
    public const string NavAccount = "Navigate to Account";
    public const string NavUpgrade = "Navigate to Upgrade";
}
