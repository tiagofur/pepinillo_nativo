using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using Pepinillo.Core.Models;
using Pepinillo.Core.Services;
using Pepinillo.Core.Utilities;

namespace Pepinillo.Core.ViewModels;

public partial class SettingsViewModel : ObservableObject
{
    private readonly ISettingsService _settingsService;
    private readonly ILocalizationService? _localizer;
    private readonly IEntitlementService? _entitlements;
    private readonly IFocusAssistService? _focusAssist;
    private bool _suppressThemeIndexChange;

    /// <summary>
    /// Raised after settings are saved so the shell can apply theme / OS intent flags.
    /// </summary>
    public event EventHandler<UserSettings>? SettingsSaved;

    /// <summary>Raised when a premium theme is selected on free tier (shell navigates to paywall).</summary>
    public event EventHandler<string>? PremiumFeatureRequested;

    /// <summary>Raised after the user asks to replay first-run onboarding (shell navigates).</summary>
    public event EventHandler? OnboardingReplayRequested;

    [ObservableProperty]
    private UserSettings _settings = new();

    [ObservableProperty]
    private bool _isBusy;

    [ObservableProperty]
    private string _statusMessage = string.Empty;

    [ObservableProperty]
    private int _selectedThemeIndex;

    [ObservableProperty]
    private int _selectedLanguageIndex;

    [ObservableProperty]
    private string _titleLabel = "Settings";

    [ObservableProperty]
    private string _timerDurationsLabel = "Timer durations";

    [ObservableProperty]
    private string _pomodoroFocusLabel = "Pomodoro focus (minutes)";

    [ObservableProperty]
    private string _shortBreakLabel = "Short break (minutes)";

    [ObservableProperty]
    private string _longBreakLabel = "Long break (minutes)";

    [ObservableProperty]
    private string _longBreakIntervalLabel = "Long break every N pomodoros";

    [ObservableProperty]
    private string _flowtimeTargetLabel = "Flowtime target (minutes)";

    [ObservableProperty]
    private string _timeBlockLabel = "Time block (minutes)";

    [ObservableProperty]
    private string _autoStartBreaksLabel = "Auto-start breaks";

    [ObservableProperty]
    private string _autoStartFocusLabel = "Auto-start next focus after break";

    [ObservableProperty]
    private string _appearanceLabel = "Appearance";

    [ObservableProperty]
    private string _saveLabel = "Save settings";

    [ObservableProperty]
    private string _languageLabel = "Language";

    [ObservableProperty]
    private string _languageAppliesNote =
        "Language applies to screens when reopened.";

    [ObservableProperty]
    private string _privacyLabel = "Privacy policy";

    [ObservableProperty]
    private string _termsLabel = "Terms of use";

    [ObservableProperty]
    private string _upgradeLabel = "Upgrade";

    [ObservableProperty]
    private string _upgradePlusLabel = "Upgrade to Pepinillo+";

    [ObservableProperty]
    private string _micaLabel = "Mica / acrylic backdrop (when supported)";

    [ObservableProperty]
    private string _soundscapesSectionLabel = "Soundscapes";

    [ObservableProperty]
    private string _enableSoundscapesLabel = "Enable soundscapes";

    [ObservableProperty]
    private string _autoPlaySoundscapeLabel =
        "Auto-play preferred soundscape when focus starts";

    [ObservableProperty]
    private string _soundscapesHintLabel =
        "Master volume and track selection live on the Soundscapes page. Preferred track updates when you press Play.";

    [ObservableProperty]
    private string _windowsIntegrationLabel = "Windows integration";

    [ObservableProperty]
    private string _focusAssistLabel = "Sync with Focus Assist / Do Not Disturb";

    [ObservableProperty]
    private string _openFocusAssistLabel = "Open Focus Assist settings";

    [ObservableProperty]
    private string _minimizeToTrayLabel = "Minimize to system tray on close";

    [ObservableProperty]
    private string _toastsLabel = "Toast notifications";

    [ObservableProperty]
    private string _startupLabel = "Launch Pepinillo when Windows starts";

    [ObservableProperty]
    private string _hotkeysLabel = "Global hotkeys";

    [ObservableProperty]
    private string _playPauseHotkeyLabel = "Play / Pause";

    [ObservableProperty]
    private string _skipHotkeyLabel = "Skip break";

    [ObservableProperty]
    private string _miniTimerHotkeyLabel = "Mini timer";

    [ObservableProperty]
    private string _resetHotkeysLabel = "Reset hotkeys to defaults";

    [ObservableProperty]
    private string _helpLabel = "Help";

    [ObservableProperty]
    private string _onboardingReplayLabel =
        "Replay the first-run welcome guide (modes, tray, hotkeys, mini timer).";

    [ObservableProperty]
    private string _onboardingReplayButtonLabel = "Show welcome guide";

    [ObservableProperty]
    private string _legalLabel = "Legal";

    /// <summary>
    /// Non-empty when the last theme pick was blocked by free-tier limits.
    /// </summary>
    [ObservableProperty]
    private string _paywallFeatureHint = string.Empty;

    /// <summary>Honest Focus Assist / DND diagnostic from the platform service.</summary>
    [ObservableProperty]
    private string _focusAssistStatus = string.Empty;

    /// <summary>Validation / OS note under hotkey editors.</summary>
    [ObservableProperty]
    private string _hotkeyHint =
        "If a hotkey does nothing, another app may own the chord (e.g. PowerToys).";

    /// <summary>In-app page accelerators (Focus/Tasks) documented for keyboard-first users.</summary>
    [ObservableProperty]
    private string _keyboardAcceleratorsCaption =
        "Focus: Ctrl+Enter start/resume · Ctrl+Space pause when available. Tasks: Ctrl+N focus add field.";

    public string[] LanguageOptions { get; } = { "en", "es", "pt" };

    /// <summary>Theme picker options (System, Light, Dark, Forest, Ocean, Sunset).</summary>
    public IReadOnlyList<AppThemeInfo> ThemeOptions => AppThemeCatalog.All;

    public SettingsViewModel(
        ISettingsService settingsService,
        ILocalizationService? localizer = null,
        IEntitlementService? entitlements = null,
        IFocusAssistService? focusAssist = null)
    {
        _settingsService = settingsService;
        _localizer = localizer;
        _entitlements = entitlements;
        _focusAssist = focusAssist;
    }

    public async Task LoadAsync()
    {
        IsBusy = true;
        try
        {
            Settings = await _settingsService.GetSettingsAsync();
            // Normalize OLEDBlack → Dark for picker without rewriting until save.
            var themeForUi = AppThemeCatalog.Normalize(Settings.SelectedTheme);
            if (!CanUseTheme(themeForUi))
            {
                // Premium theme stored but entitlement lapsed — fall back to Dark free.
                themeForUi = "Dark";
                Settings.SelectedTheme = themeForUi;
            }

            _suppressThemeIndexChange = true;
            SelectedThemeIndex = AppThemeCatalog.ToIndex(themeForUi);
            _suppressThemeIndexChange = false;

            SelectedLanguageIndex = LanguageToIndex(Settings.PreferredLanguage);
            _localizer?.SetLanguage(Settings.PreferredLanguage);
            ApplyLocalizedLabels();
            StatusMessage = string.Empty;
            PaywallFeatureHint = string.Empty;
            FocusAssistStatus = _focusAssist?.FocusAssistStatus
                ?? T("Settings.FocusAssistUnavailable", "Focus Assist: status unavailable");
        }
        finally
        {
            IsBusy = false;
        }
    }

    [RelayCommand]
    private async Task SaveSettingsAsync()
    {
        IsBusy = true;
        try
        {
            var theme = AppThemeCatalog.FromIndex(SelectedThemeIndex);
            if (!CanUseTheme(theme))
            {
                BlockPremiumTheme(theme);
                return;
            }

            if (!TryNormalizeHotkeys(out var hotkeyError))
            {
                StatusMessage = hotkeyError;
                return;
            }

            Settings.SelectedTheme = theme;
            Settings.PreferredLanguage = IndexToLanguage(SelectedLanguageIndex);
            await _settingsService.SaveSettingsAsync(Settings);
            _localizer?.SetLanguage(Settings.PreferredLanguage);
            ApplyLocalizedLabels();
            StatusMessage = T("Settings.Saved", "Settings saved");
            PaywallFeatureHint = string.Empty;
            FocusAssistStatus = _focusAssist?.FocusAssistStatus
                ?? FocusAssistStatus;
            SettingsSaved?.Invoke(this, Settings);
        }
        catch (Exception ex)
        {
            StatusMessage = string.Format(
                T("Settings.SaveFailed", "Save failed: {0}"),
                ex.Message);
        }
        finally
        {
            IsBusy = false;
        }
    }

    [RelayCommand]
    private void ResetHotkeys()
    {
        Settings.PlayPauseHotkey = HotkeyChordParser.DefaultPlayPause;
        Settings.SkipHotkey = HotkeyChordParser.DefaultSkip;
        Settings.MiniTimerHotkey = HotkeyChordParser.DefaultMiniTimer;
        OnPropertyChanged(nameof(Settings));
        StatusMessage = T("Settings.HotkeysReset",
            "Hotkeys reset to defaults (save to apply).");
    }

    /// <summary>
    /// Clears the onboarding completion flag and asks the shell to show the welcome guide again.
    /// </summary>
    [RelayCommand]
    private async Task ReplayOnboardingAsync()
    {
        IsBusy = true;
        try
        {
            Settings.HasCompletedOnboarding = false;
            await _settingsService.SaveSettingsAsync(Settings);
            StatusMessage = T("Settings.OpeningOnboarding", "Opening welcome guide…");
            OnboardingReplayRequested?.Invoke(this, EventArgs.Empty);
        }
        catch (Exception ex)
        {
            StatusMessage = string.Format(
                T("Settings.SaveFailed", "Save failed: {0}"),
                ex.Message);
        }
        finally
        {
            IsBusy = false;
        }
    }

    /// <summary>
    /// Validates and normalizes hotkey strings. Returns false with a message on invalid input.
    /// </summary>
    private bool TryNormalizeHotkeys(out string error)
    {
        error = string.Empty;

        if (!HotkeyChordParser.TryParse(Settings.PlayPauseHotkey, out var play))
        {
            error = T("Settings.HotkeyInvalidPlay",
                "Play/Pause hotkey is invalid. Use e.g. Win+Shift+P.");
            return false;
        }

        if (!HotkeyChordParser.TryParse(Settings.SkipHotkey, out var skip))
        {
            error = T("Settings.HotkeyInvalidSkip",
                "Skip hotkey is invalid. Use e.g. Win+Shift+S.");
            return false;
        }

        if (!HotkeyChordParser.TryParse(Settings.MiniTimerHotkey, out var mini))
        {
            error = T("Settings.HotkeyInvalidMini",
                "Mini timer hotkey is invalid. Use e.g. Win+Shift+M.");
            return false;
        }

        Settings.PlayPauseHotkey = play.Format();
        Settings.SkipHotkey = skip.Format();
        Settings.MiniTimerHotkey = mini.Format();

        // Soft collision check (same chord on two slots).
        if (string.Equals(Settings.PlayPauseHotkey, Settings.SkipHotkey, StringComparison.OrdinalIgnoreCase)
            || string.Equals(Settings.PlayPauseHotkey, Settings.MiniTimerHotkey, StringComparison.OrdinalIgnoreCase)
            || string.Equals(Settings.SkipHotkey, Settings.MiniTimerHotkey, StringComparison.OrdinalIgnoreCase))
        {
            error = T("Settings.HotkeysMustBeUnique",
                "Hotkeys must be unique across Play/Pause, Skip, and Mini timer.");
            return false;
        }

        return true;
    }

    [RelayCommand]
    private async Task SelectThemeAsync(string themeName)
    {
        if (string.IsNullOrWhiteSpace(themeName))
            return;

        var normalized = AppThemeCatalog.Normalize(themeName);
        if (!CanUseTheme(normalized))
        {
            BlockPremiumTheme(normalized);
            return;
        }

        Settings.SelectedTheme = normalized;
        _suppressThemeIndexChange = true;
        SelectedThemeIndex = AppThemeCatalog.ToIndex(normalized);
        _suppressThemeIndexChange = false;
        OnPropertyChanged(nameof(Settings));
        await SaveSettingsAsync();
    }

    partial void OnSelectedThemeIndexChanged(int value)
    {
        if (_suppressThemeIndexChange)
            return;

        var theme = AppThemeCatalog.FromIndex(value);
        if (!CanUseTheme(theme))
        {
            BlockPremiumTheme(theme);
            _suppressThemeIndexChange = true;
            SelectedThemeIndex = AppThemeCatalog.ToIndex(Settings.SelectedTheme);
            _suppressThemeIndexChange = false;
            return;
        }

        Settings.SelectedTheme = theme;
        StatusMessage = string.Empty;
        PaywallFeatureHint = string.Empty;
    }

    partial void OnSelectedLanguageIndexChanged(int value)
    {
        Settings.PreferredLanguage = IndexToLanguage(value);
    }

    private bool CanUseTheme(string themeName) =>
        _entitlements == null || _entitlements.CanUseTheme(themeName);

    private void BlockPremiumTheme(string themeName)
    {
        StatusMessage = T("Settings.PremiumThemesUpgrade",
            "Upgrade to Pepinillo+ for premium themes.");
        PaywallFeatureHint = themeName;
        PremiumFeatureRequested?.Invoke(this, themeName);
    }

    private void ApplyLocalizedLabels()
    {
        if (_localizer == null) return;
        TitleLabel = _localizer.GetString("Settings.Title");
        TimerDurationsLabel = _localizer.GetString("Settings.TimerDurations");
        PomodoroFocusLabel = _localizer.GetString("Settings.PomodoroFocus");
        ShortBreakLabel = _localizer.GetString("Settings.ShortBreak");
        LongBreakLabel = _localizer.GetString("Settings.LongBreak");
        LongBreakIntervalLabel = _localizer.GetString("Settings.LongBreakInterval");
        FlowtimeTargetLabel = _localizer.GetString("Settings.FlowtimeTarget");
        TimeBlockLabel = _localizer.GetString("Settings.TimeBlock");
        AutoStartBreaksLabel = _localizer.GetString("Settings.AutoStartBreaks");
        AutoStartFocusLabel = _localizer.GetString("Settings.AutoStartFocus");
        AppearanceLabel = _localizer.GetString("Settings.Appearance");
        SaveLabel = _localizer.GetString("Settings.Save");
        LanguageLabel = _localizer.GetString("Settings.Language");
        LanguageAppliesNote = _localizer.GetString("Settings.LanguageAppliesNote");
        PrivacyLabel = _localizer.GetString("Settings.Privacy");
        TermsLabel = _localizer.GetString("Settings.Terms");
        UpgradeLabel = _localizer.GetString("Settings.Upgrade");
        UpgradePlusLabel = _localizer.GetString("Settings.UpgradePlus");
        MicaLabel = _localizer.GetString("Settings.Mica");
        SoundscapesSectionLabel = _localizer.GetString("Settings.SoundscapesSection");
        EnableSoundscapesLabel = _localizer.GetString("Settings.EnableSoundscapes");
        AutoPlaySoundscapeLabel = _localizer.GetString("Settings.AutoPlaySoundscape");
        SoundscapesHintLabel = _localizer.GetString("Settings.SoundscapesHint");
        WindowsIntegrationLabel = _localizer.GetString("Settings.WindowsIntegration");
        FocusAssistLabel = _localizer.GetString("Settings.FocusAssist");
        OpenFocusAssistLabel = _localizer.GetString("Settings.OpenFocusAssist");
        MinimizeToTrayLabel = _localizer.GetString("Settings.MinimizeToTray");
        ToastsLabel = _localizer.GetString("Settings.Toasts");
        StartupLabel = _localizer.GetString("Settings.Startup");
        HotkeysLabel = _localizer.GetString("Settings.Hotkeys");
        HotkeyHint = _localizer.GetString("Settings.HotkeyHint");
        KeyboardAcceleratorsCaption = _localizer.GetString("Settings.KeyboardAcceleratorsCaption");
        PlayPauseHotkeyLabel = _localizer.GetString("Settings.PlayPauseHotkey");
        SkipHotkeyLabel = _localizer.GetString("Settings.SkipHotkey");
        MiniTimerHotkeyLabel = _localizer.GetString("Settings.MiniTimerHotkey");
        ResetHotkeysLabel = _localizer.GetString("Settings.ResetHotkeys");
        HelpLabel = _localizer.GetString("Settings.Help");
        OnboardingReplayLabel = _localizer.GetString("Settings.OnboardingReplay");
        OnboardingReplayButtonLabel = _localizer.GetString("Settings.OnboardingReplayButton");
        LegalLabel = _localizer.GetString("Settings.Legal");
    }

    private string T(string key, string fallback) =>
        _localizer?.GetString(key) ?? fallback;

    private static int LanguageToIndex(string lang) => lang switch
    {
        "es" => 1,
        "pt" => 2,
        _ => 0
    };

    private static string IndexToLanguage(int index) => index switch
    {
        1 => "es",
        2 => "pt",
        _ => "en"
    };
}
