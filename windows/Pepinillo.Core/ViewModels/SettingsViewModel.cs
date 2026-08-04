using System;
using System.Threading.Tasks;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using Pepinillo.Core.Models;
using Pepinillo.Core.Services;

namespace Pepinillo.Core.ViewModels;

public partial class SettingsViewModel : ObservableObject
{
    private readonly ISettingsService _settingsService;
    private readonly ILocalizationService? _localizer;

    /// <summary>
    /// Raised after settings are saved so the shell can apply theme / OS intent flags.
    /// </summary>
    public event EventHandler<UserSettings>? SettingsSaved;

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

    public string[] LanguageOptions { get; } = { "en", "es", "pt" };

    public SettingsViewModel(ISettingsService settingsService, ILocalizationService? localizer = null)
    {
        _settingsService = settingsService;
        _localizer = localizer;
    }

    public async Task LoadAsync()
    {
        IsBusy = true;
        try
        {
            Settings = await _settingsService.GetSettingsAsync();
            SelectedThemeIndex = ThemeToIndex(Settings.SelectedTheme);
            SelectedLanguageIndex = LanguageToIndex(Settings.PreferredLanguage);
            _localizer?.SetLanguage(Settings.PreferredLanguage);
            ApplyLocalizedLabels();
            StatusMessage = string.Empty;
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
            Settings.SelectedTheme = IndexToTheme(SelectedThemeIndex);
            Settings.PreferredLanguage = IndexToLanguage(SelectedLanguageIndex);
            await _settingsService.SaveSettingsAsync(Settings);
            _localizer?.SetLanguage(Settings.PreferredLanguage);
            ApplyLocalizedLabels();
            StatusMessage = _localizer?.GetString("Settings.Saved") ?? "Settings saved";
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
    private async Task SelectThemeAsync(string themeName)
    {
        if (string.IsNullOrWhiteSpace(themeName))
            return;

        Settings.SelectedTheme = themeName;
        SelectedThemeIndex = ThemeToIndex(themeName);
        OnPropertyChanged(nameof(Settings));
        await SaveSettingsAsync();
    }

    partial void OnSelectedThemeIndexChanged(int value)
    {
        Settings.SelectedTheme = IndexToTheme(value);
    }

    partial void OnSelectedLanguageIndexChanged(int value)
    {
        Settings.PreferredLanguage = IndexToLanguage(value);
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

    private static int ThemeToIndex(string theme) => theme switch
    {
        "Dark" => 1,
        "Light" => 2,
        "Forest" => 3,
        "Ocean" => 4,
        "OLEDBlack" => 5,
        _ => 0 // System
    };

    private static string IndexToTheme(int index) => index switch
    {
        1 => "Dark",
        2 => "Light",
        3 => "Forest",
        4 => "Ocean",
        5 => "OLEDBlack",
        _ => "System"
    };

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
