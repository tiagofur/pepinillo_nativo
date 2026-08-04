using System;
using System.Threading.Tasks;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using Pepinillo.Core.Models;
using Pepinillo.Core.Services;

namespace Pepinillo.Core.ViewModels;

/// <summary>
/// First-run Windows onboarding (W7): Welcome → Modes → Desktop power → Account teaser → Done.
/// Skip and Finish both persist <see cref="UserSettings.HasCompletedOnboarding"/>.
/// </summary>
public partial class OnboardingViewModel : ObservableObject
{
    public const int StepCount = 5;

    private readonly ISettingsService _settingsService;
    private readonly ILocalizationService? _localizer;

    /// <summary>Raised after Skip or Finish successfully saves completion.</summary>
    public event EventHandler? Completed;

    [ObservableProperty]
    [NotifyPropertyChangedFor(nameof(IsFirstStep))]
    [NotifyPropertyChangedFor(nameof(IsLastStep))]
    [NotifyPropertyChangedFor(nameof(CanGoBack))]
    [NotifyPropertyChangedFor(nameof(PrimaryButtonLabel))]
    [NotifyPropertyChangedFor(nameof(StepProgressLabel))]
    [NotifyPropertyChangedFor(nameof(IsWelcomeStep))]
    [NotifyPropertyChangedFor(nameof(IsModesStep))]
    [NotifyPropertyChangedFor(nameof(IsDesktopStep))]
    [NotifyPropertyChangedFor(nameof(IsAccountStep))]
    [NotifyPropertyChangedFor(nameof(IsDoneStep))]
    [NotifyPropertyChangedFor(nameof(StepTitle))]
    [NotifyPropertyChangedFor(nameof(StepBody))]
    private int _currentStep;

    [ObservableProperty]
    [NotifyPropertyChangedFor(nameof(IsPomodoroSelected))]
    [NotifyPropertyChangedFor(nameof(IsStopwatchSelected))]
    [NotifyPropertyChangedFor(nameof(IsFlowtimeSelected))]
    [NotifyPropertyChangedFor(nameof(IsTimeBlockingSelected))]
    private FocusMode _selectedDefaultMode = FocusMode.Pomodoro;

    [ObservableProperty]
    private bool _isBusy;

    [ObservableProperty]
    private string _statusMessage = string.Empty;

    public bool IsFirstStep => CurrentStep <= 0;
    public bool IsLastStep => CurrentStep >= StepCount - 1;
    public bool CanGoBack => CurrentStep > 0;

    public string PrimaryButtonLabel => IsLastStep
        ? T("Onboarding.GetStarted", "Get started")
        : T("Onboarding.Next", "Next");

    public string StepProgressLabel
    {
        get
        {
            var step = Math.Clamp(CurrentStep, 0, StepCount - 1) + 1;
            var template = T("Onboarding.StepProgress", "Step {0} of {1}");
            return string.Format(template, step, StepCount);
        }
    }

    public bool IsWelcomeStep => CurrentStep == 0;
    public bool IsModesStep => CurrentStep == 1;
    public bool IsDesktopStep => CurrentStep == 2;
    public bool IsAccountStep => CurrentStep == 3;
    public bool IsDoneStep => CurrentStep == 4;

    public bool IsPomodoroSelected => SelectedDefaultMode == FocusMode.Pomodoro;
    public bool IsStopwatchSelected => SelectedDefaultMode == FocusMode.Stopwatch;
    public bool IsFlowtimeSelected => SelectedDefaultMode == FocusMode.Flowtime;
    public bool IsTimeBlockingSelected => SelectedDefaultMode == FocusMode.TimeBlocking;

    public string StepTitle => CurrentStep switch
    {
        0 => T("Onboarding.StepTitle0", "Welcome to Pepinillo"),
        1 => T("Onboarding.StepTitle1", "Four ways to focus"),
        2 => T("Onboarding.StepTitle2", "Desktop power"),
        3 => T("Onboarding.StepTitle3", "Optional account"),
        4 => T("Onboarding.StepTitle4", "You're ready"),
        _ => T("Onboarding.StepTitle0", "Welcome to Pepinillo")
    };

    public string StepBody => CurrentStep switch
    {
        0 => T("Onboarding.StepBody0",
            "Deep Work OS for Windows — timers, tasks, analytics, and ambient soundscapes. Built for long sessions at your desk."),
        1 => T("Onboarding.StepBody1",
            "Pick a default mode. Pomodoro and Stopwatch are free. Flowtime and Time Blocking unlock with Pepinillo+."),
        2 => T("Onboarding.StepBody2",
            "Close to the tray, use global hotkeys, and keep a mini timer on top while you work in other apps."),
        3 => T("Onboarding.StepBody3",
            "Stay local forever, or sign in later for Everywhere cloud session sync. You can skip this for now."),
        4 => T("Onboarding.StepBody4",
            "Start a session from Focus. Open Settings anytime to replay this guide or tune durations and hotkeys."),
        _ => string.Empty
    };

    public string DesktopTrayLine => T("Onboarding.DesktopTray",
        "System tray — minimize or close keeps Pepinillo running in the background.");
    public string DesktopHotkeysLine => T("Onboarding.DesktopHotkeys",
        "Hotkeys — Win+Shift+P play/pause · Win+Shift+S skip break · Win+Shift+M mini timer.");
    public string DesktopMiniLine => T("Onboarding.DesktopMini",
        "Mini timer — compact always-on-top overlay for multi-tasking.");
    public string AccountTeaserLine => T("Onboarding.AccountTeaser",
        "Account is optional. Free and paid local features work offline without signing in.");
    public string SkipLabel => T("Onboarding.Skip", "Skip");
    public string BackLabel => T("Onboarding.Back", "Back");

    public OnboardingViewModel(
        ISettingsService settingsService,
        ILocalizationService? localizer = null)
    {
        _settingsService = settingsService;
        _localizer = localizer;
    }

    /// <summary>
    /// Applies preferred language from settings so step titles/bodies recompute.
    /// </summary>
    public async Task ApplyLanguageFromSettingsAsync()
    {
        if (_localizer == null) return;
        try
        {
            var settings = await _settingsService.GetSettingsAsync();
            _localizer.SetLanguage(settings.PreferredLanguage);
            NotifyLocalizedProperties();
        }
        catch
        {
            // keep defaults
        }
    }

    [RelayCommand]
    private async Task NextAsync()
    {
        if (IsLastStep)
        {
            await FinishAsync();
            return;
        }

        CurrentStep = Math.Min(CurrentStep + 1, StepCount - 1);
        BackCommand.NotifyCanExecuteChanged();
    }

    [RelayCommand(CanExecute = nameof(CanGoBack))]
    private void Back()
    {
        if (CurrentStep <= 0)
            return;

        CurrentStep--;
        BackCommand.NotifyCanExecuteChanged();
    }

    [RelayCommand]
    private async Task SkipAsync() => await CompleteOnboardingAsync();

    [RelayCommand]
    private async Task FinishAsync() => await CompleteOnboardingAsync();

    [RelayCommand]
    private void SelectMode(string? modeName)
    {
        if (string.IsNullOrWhiteSpace(modeName))
            return;

        if (Enum.TryParse<FocusMode>(modeName, ignoreCase: true, out var mode))
            SelectedDefaultMode = mode;
    }

    /// <summary>
    /// Resets the wizard to step 0 (e.g. when replaying from Settings).
    /// Does not clear the completion flag — call that separately before showing.
    /// </summary>
    public void ResetWizard()
    {
        CurrentStep = 0;
        SelectedDefaultMode = FocusMode.Pomodoro;
        StatusMessage = string.Empty;
        BackCommand.NotifyCanExecuteChanged();
        NotifyLocalizedProperties();
    }

    private async Task CompleteOnboardingAsync()
    {
        if (IsBusy)
            return;

        IsBusy = true;
        try
        {
            var settings = await _settingsService.GetSettingsAsync();
            settings.HasCompletedOnboarding = true;
            settings.PreferredFocusMode = SelectedDefaultMode.ToString();
            await _settingsService.SaveSettingsAsync(settings);
            StatusMessage = string.Empty;
            Completed?.Invoke(this, EventArgs.Empty);
        }
        catch (Exception ex)
        {
            var template = T("Onboarding.SaveFailed", "Could not save onboarding: {0}");
            StatusMessage = string.Format(template, ex.Message);
        }
        finally
        {
            IsBusy = false;
        }
    }

    private void NotifyLocalizedProperties()
    {
        OnPropertyChanged(nameof(StepTitle));
        OnPropertyChanged(nameof(StepBody));
        OnPropertyChanged(nameof(PrimaryButtonLabel));
        OnPropertyChanged(nameof(StepProgressLabel));
        OnPropertyChanged(nameof(DesktopTrayLine));
        OnPropertyChanged(nameof(DesktopHotkeysLine));
        OnPropertyChanged(nameof(DesktopMiniLine));
        OnPropertyChanged(nameof(AccountTeaserLine));
        OnPropertyChanged(nameof(SkipLabel));
        OnPropertyChanged(nameof(BackLabel));
    }

    private string T(string key, string fallback) =>
        _localizer?.GetString(key) ?? fallback;
}
