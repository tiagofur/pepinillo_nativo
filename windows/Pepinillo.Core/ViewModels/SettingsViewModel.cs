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
    private string _privacyLabel = "Privacy policy";

    [ObservableProperty]
    private string _termsLabel = "Terms of use";

    [ObservableProperty]
    private string _upgradeLabel = "Upgrade";

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
                ?? "Focus Assist: status unavailable";
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
            StatusMessage = _localizer?.GetString("Settings.Saved") ?? "Settings saved";
            PaywallFeatureHint = string.Empty;
            FocusAssistStatus = _focusAssist?.FocusAssistStatus
                ?? FocusAssistStatus;
            SettingsSaved?.Invoke(this, Settings);
        }
        catch (Exception ex)
        {
            StatusMessage = $"Save failed: {ex.Message}";
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
        StatusMessage = "Hotkeys reset to defaults (save to apply).";
    }

    /// <summary>
    /// Validates and normalizes hotkey strings. Returns false with a message on invalid input.
    /// </summary>
    private bool TryNormalizeHotkeys(out string error)
    {
        error = string.Empty;

        if (!HotkeyChordParser.TryParse(Settings.PlayPauseHotkey, out var play))
        {
            error = "Play/Pause hotkey is invalid. Use e.g. Win+Shift+P.";
            return false;
        }

        if (!HotkeyChordParser.TryParse(Settings.SkipHotkey, out var skip))
        {
            error = "Skip hotkey is invalid. Use e.g. Win+Shift+S.";
            return false;
        }

        if (!HotkeyChordParser.TryParse(Settings.MiniTimerHotkey, out var mini))
        {
            error = "Mini timer hotkey is invalid. Use e.g. Win+Shift+M.";
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
            error = "Hotkeys must be unique across Play/Pause, Skip, and Mini timer.";
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
        StatusMessage = "Upgrade to Pepinillo+ for premium themes.";
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
        AutoStartBreaksLabel = _localizer.GetString("Settings.AutoStartBreaks");
        AutoStartFocusLabel = _localizer.GetString("Settings.AutoStartFocus");
        AppearanceLabel = _localizer.GetString("Settings.Appearance");
        SaveLabel = _localizer.GetString("Settings.Save");
        LanguageLabel = _localizer.GetString("Settings.Language");
        PrivacyLabel = _localizer.GetString("Settings.Privacy");
        TermsLabel = _localizer.GetString("Settings.Terms");
        UpgradeLabel = _localizer.GetString("Settings.Upgrade");
    }

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
