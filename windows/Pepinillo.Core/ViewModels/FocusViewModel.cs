using System;
using System.Collections.ObjectModel;
using System.Linq;
using System.Threading.Tasks;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using Pepinillo.Core.Models;
using Pepinillo.Core.Services;

namespace Pepinillo.Core.ViewModels;

public partial class FocusViewModel : ObservableObject
{
    private readonly IFocusEngineService _focusEngine;
    private readonly ISettingsService _settingsService;
    private readonly IFocusSessionService _sessionService;
    private readonly ITaskService _taskService;
    private readonly INotificationService _notificationService;
    private readonly IFocusAssistService _focusAssistService;
    private readonly IEntitlementService? _entitlements;
    private readonly ISyncService? _syncService;
    private readonly ILocalizationService? _localizer;
    private readonly ISoundscapeSessionCoordinator? _soundscapeCoordinator;
    private readonly IModeIntelligenceService? _modeIntelligence;
    private UserSettings _cachedSettings = new();
    private SessionState _previousState = SessionState.Idle;
    private bool _focusAssistActive;
    private bool _modeSuggestionDismissed;
    private ModeSuggestion? _pendingModeSuggestion;
    /// <summary>When true, next <see cref="InitializeAsync"/> keeps engine mode/duration (calendar Start).</summary>
    private bool _preserveConfiguredSession;

    [ObservableProperty]
    private SessionState _currentState = SessionState.Idle;

    [ObservableProperty]
    private FocusMode _selectedMode = FocusMode.Pomodoro;

    [ObservableProperty]
    private string _formattedTime = "25:00";

    [ObservableProperty]
    private double _progressRatio;

    [ObservableProperty]
    private string _statusLabel = "Ready";

    [ObservableProperty]
    private string _activeTaskTitle = "Free focus (no task linked)";

    [ObservableProperty]
    private Guid? _linkedTaskId;

    [ObservableProperty]
    private ObservableCollection<TaskItem> _availableTasks = new();

    [ObservableProperty]
    private bool _isOnBreak;

    [ObservableProperty]
    private bool _canStart = true;

    [ObservableProperty]
    private bool _canPause;

    [ObservableProperty]
    private bool _canSkip;

    [ObservableProperty]
    private string _lastCompletedMessage = string.Empty;

    [ObservableProperty]
    private FocusSession? _pendingJournalSession;

    [ObservableProperty]
    private string _journalNoteDraft = string.Empty;

    [ObservableProperty]
    private int _journalEnergyRating;

    [ObservableProperty]
    private bool _showJournalPanel;

    [ObservableProperty]
    private string _titleLabel = "Focus Engine";

    [ObservableProperty]
    private string _startLabel = "Start / Resume";

    [ObservableProperty]
    private string _pauseLabel = "Pause";

    [ObservableProperty]
    private string _stopLabel = "Stop";

    [ObservableProperty]
    private string _skipLabel = "Skip break";

    [ObservableProperty]
    private string _linkTaskLabel = "Link a task (optional)";

    [ObservableProperty]
    private string _journalTitleLabel = "Session reflection";

    /// <summary>
    /// Non-empty when the last SelectMode/Start was blocked by free-tier limits (paywall hint).
    /// </summary>
    [ObservableProperty]
    private string _paywallFeatureHint = string.Empty;

    /// <summary>Raised when a premium focus mode is requested on free tier.</summary>
    public event EventHandler<string>? PremiumFeatureRequested;

    /// <summary>Optional chip text e.g. "Soundscape: Rain" when auto-play is enabled.</summary>
    [ObservableProperty]
    private string _soundscapeChipLabel = string.Empty;

    /// <summary>Human-readable Mode Intelligence reason (or upgrade teaser on free).</summary>
    [ObservableProperty]
    private string _suggestionReason = string.Empty;

    /// <summary>Suggested mode display name for the banner title.</summary>
    [ObservableProperty]
    private string _suggestedModeLabel = string.Empty;

    /// <summary>Paid: show apply/dismiss Mode Intelligence banner.</summary>
    [ObservableProperty]
    private bool _showModeSuggestion;

    /// <summary>Free: locked golden teaser → paywall.</summary>
    [ObservableProperty]
    private bool _showModeSuggestionLocked;

    public FocusViewModel(
        IFocusEngineService focusEngine,
        ISettingsService settingsService,
        IFocusSessionService sessionService,
        ITaskService taskService,
        INotificationService notificationService,
        IFocusAssistService focusAssistService,
        ISyncService? syncService = null,
        ILocalizationService? localizer = null,
        IEntitlementService? entitlements = null,
        ISoundscapeSessionCoordinator? soundscapeCoordinator = null,
        IModeIntelligenceService? modeIntelligence = null)
    {
        _focusEngine = focusEngine;
        _settingsService = settingsService;
        _sessionService = sessionService;
        _taskService = taskService;
        _notificationService = notificationService;
        _focusAssistService = focusAssistService;
        _syncService = syncService;
        _localizer = localizer;
        _entitlements = entitlements;
        _soundscapeCoordinator = soundscapeCoordinator;
        _modeIntelligence = modeIntelligence;

        _focusEngine.StateChanged += OnEngineStateChanged;
        _focusEngine.Tick += OnEngineTick;
        _focusEngine.SessionCompleted += OnEngineSessionCompleted;

        ApplyLocalizedLabels();
        UpdateTimerDisplay();
        UpdateCommandFlags();
    }

    public async Task InitializeAsync()
    {
        _cachedSettings = await _settingsService.GetSettingsAsync();
        ApplySettingsToEngine(_cachedSettings);
        ApplyLanguage(_cachedSettings.PreferredLanguage);

        if (_preserveConfiguredSession)
        {
            // Calendar (or other external) already configured mode/duration/task — do not clobber.
            SelectedMode = _focusEngine.CurrentMode;
            LinkedTaskId = _focusEngine.LinkedTaskId;
            if (LinkedTaskId == null)
                ActiveTaskTitle = FreeFocusLabel();
            UpdateTimerDisplay();
            _preserveConfiguredSession = false;
        }
        else
        {
            TryApplyPreferredFocusMode(_cachedSettings);

            if (_focusEngine.CurrentState == SessionState.Idle && !_focusEngine.IsOnBreak)
            {
                var duration = ResolveDurationSeconds(SelectedMode, _cachedSettings);
                _focusEngine.ConfigureSession(SelectedMode, duration, LinkedTaskId);
                UpdateTimerDisplay();
            }
        }

        await LoadAvailableTasksAsync();
        await RefreshSoundscapeChipAsync();
        await RefreshModeSuggestionAsync();
        UpdateCommandFlags();
    }

    /// <summary>
    /// Configures Time Blocking from the day planner (W13). Does not auto-start — user presses Start on Focus.
    /// Returns false when free-tier blocked or a non-idle session is running.
    /// </summary>
    public bool TryConfigureTimeBlock(int durationMinutes, Guid? taskId, string? taskTitle = null)
    {
        if (CurrentState is SessionState.Running or SessionState.Paused or SessionState.Break)
            return false;

        if (!EnsureModeAllowed(FocusMode.TimeBlocking))
            return false;

        PaywallFeatureHint = string.Empty;
        SelectedMode = FocusMode.TimeBlocking;
        LinkedTaskId = taskId;
        ActiveTaskTitle = taskId == null
            ? FreeFocusLabel()
            : (string.IsNullOrWhiteSpace(taskTitle) ? FreeFocusLabel() : taskTitle.Trim());

        ApplySettingsToEngine(_cachedSettings);
        var durationSeconds = Math.Max(60, durationMinutes * 60);
        _focusEngine.ConfigureSession(FocusMode.TimeBlocking, durationSeconds, taskId);
        _preserveConfiguredSession = true;
        UpdateTimerDisplay();
        UpdateCommandFlags();
        return true;
    }

    /// <summary>
    /// Applies onboarding / settings preferred mode when idle and the tier allows it.
    /// </summary>
    private void TryApplyPreferredFocusMode(UserSettings settings)
    {
        if (_focusEngine.CurrentState != SessionState.Idle || _focusEngine.IsOnBreak)
            return;

        if (!Enum.TryParse<FocusMode>(settings.PreferredFocusMode, ignoreCase: true, out var preferred))
            return;

        if (_entitlements != null && !_entitlements.CanUseFocusMode(preferred))
            preferred = FocusMode.Pomodoro;

        SelectedMode = preferred;
    }

    /// <summary>
    /// Reloads settings cache (e.g. after Settings page save) without resetting the engine mid-session.
    /// </summary>
    public async Task RefreshSettingsAsync()
    {
        _cachedSettings = await _settingsService.GetSettingsAsync();
        ApplySettingsToEngine(_cachedSettings);
        ApplyLanguage(_cachedSettings.PreferredLanguage);
        await RefreshSoundscapeChipAsync();
    }

    private void ApplyLanguage(string language)
    {
        if (_localizer == null) return;
        _localizer.SetLanguage(language);
        ApplyLocalizedLabels();
    }

    private void ApplyLocalizedLabels()
    {
        if (_localizer == null) return;
        TitleLabel = _localizer.GetString("Focus.Title");
        StartLabel = _localizer.GetString("Focus.Start");
        PauseLabel = _localizer.GetString("Focus.Pause");
        StopLabel = _localizer.GetString("Focus.Stop");
        SkipLabel = _localizer.GetString("Focus.SkipBreak");
        LinkTaskLabel = _localizer.GetString("Focus.LinkTask");
        JournalTitleLabel = _localizer.GetString("Focus.JournalTitle");
        if (CurrentState == SessionState.Idle)
            StatusLabel = _localizer.GetString("Focus.Ready");
        if (LinkedTaskId == null)
            ActiveTaskTitle = FreeFocusLabel();
    }

    private string FreeFocusLabel() =>
        T("Focus.FreeFocus", "Free focus (no task linked)");

    private string ModeDisplayName(FocusMode mode) => mode switch
    {
        FocusMode.Pomodoro => T("Focus.ModePomodoro", "Pomodoro"),
        FocusMode.Stopwatch => T("Focus.ModeStopwatch", "Stopwatch"),
        FocusMode.Flowtime => T("Focus.ModeFlowtime", "Flowtime"),
        FocusMode.TimeBlocking => T("Focus.ModeTimeBlocking", "Time Blocking"),
        _ => mode.ToString()
    };

    private string T(string key, string fallback) =>
        _localizer?.GetString(key) ?? fallback;


    private void ApplySettingsToEngine(UserSettings settings)
    {
        _cachedSettings = settings;
        _focusEngine.ApplyBreakSettings(
            shortBreakSeconds: settings.ShortBreakMinutes * 60,
            longBreakSeconds: settings.LongBreakMinutes * 60,
            longBreakInterval: settings.LongBreakInterval,
            autoStartBreaks: settings.AutoStartBreaks,
            autoStartFocus: settings.AutoStartFocusSessions);
    }

    private static int ResolveDurationSeconds(FocusMode mode, UserSettings settings) => mode switch
    {
        FocusMode.Pomodoro => settings.PomodoroFocusMinutes * 60,
        FocusMode.Flowtime => settings.FlowtimeTargetMinutes * 60,
        FocusMode.TimeBlocking => Math.Max(60, settings.TimeBlockingMinutes * 60),
        FocusMode.Stopwatch => 0,
        _ => settings.PomodoroFocusMinutes * 60
    };

    [RelayCommand]
    private void StartSession()
    {
        if (!EnsureModeAllowed(SelectedMode))
            return;

        ApplySettingsToEngine(_cachedSettings);
        PaywallFeatureHint = string.Empty;

        if (CurrentState is SessionState.Idle or SessionState.Completed)
        {
            var duration = ResolveDurationSeconds(SelectedMode, _cachedSettings);
            _focusEngine.ConfigureSession(SelectedMode, duration, LinkedTaskId);
        }

        _focusEngine.Start();
        UpdateCommandFlags();
    }

    [RelayCommand]
    private void PauseSession()
    {
        if (CurrentState is SessionState.Running or SessionState.Break)
            _focusEngine.Pause();
        UpdateCommandFlags();
    }

    [RelayCommand]
    private void StopSession()
    {
        _focusEngine.Stop();
        UpdateTimerDisplay();
        UpdateCommandFlags();
    }

    [RelayCommand]
    private void SkipBreak()
    {
        _focusEngine.SkipBreak();
        UpdateTimerDisplay();
        UpdateCommandFlags();
    }

    /// <summary>
    /// Toggles play/pause for tray and global hotkey callers.
    /// </summary>
    public void TogglePlayPause()
    {
        if (CurrentState is SessionState.Running or SessionState.Break)
            PauseSession();
        else
            StartSession();
    }

    /// <summary>
    /// Skips the current break when applicable (hotkey / tray).
    /// </summary>
    public void SkipOrAdvance()
    {
        if (CanSkip)
            SkipBreak();
    }

    [RelayCommand]
    private void SelectMode(FocusMode mode)
    {
        if (CurrentState is not (SessionState.Idle or SessionState.Completed))
            return;

        if (!EnsureModeAllowed(mode))
            return;

        PaywallFeatureHint = string.Empty;
        SelectedMode = mode;
        ApplySettingsToEngine(_cachedSettings);
        var duration = ResolveDurationSeconds(mode, _cachedSettings);
        _focusEngine.ConfigureSession(mode, duration, LinkedTaskId);
        UpdateTimerDisplay();
        UpdateCommandFlags();
    }

    /// <summary>
    /// Blocks Flowtime / TimeBlocking on free tier; sets status + paywall hint.
    /// </summary>
    private bool EnsureModeAllowed(FocusMode mode)
    {
        if (_entitlements == null || _entitlements.CanUseFocusMode(mode))
            return true;

        var feature = ModeDisplayName(mode);

        StatusLabel = string.Format(
            T("Focus.ModeRequiresUpgrade", "{0} requires Pepinillo+ or Everywhere."),
            feature);
        PaywallFeatureHint = feature;
        PremiumFeatureRequested?.Invoke(this, feature);
        return false;
    }

    [RelayCommand]
    private async Task LinkTask(TaskItem? task)
    {
        if (CurrentState is not (SessionState.Idle or SessionState.Completed))
            return;

        LinkedTaskId = task?.Id;
        ActiveTaskTitle = task?.Title ?? FreeFocusLabel();
        _modeSuggestionDismissed = false;

        var duration = ResolveDurationSeconds(SelectedMode, _cachedSettings);
        _focusEngine.ConfigureSession(SelectedMode, duration, LinkedTaskId);
        await RefreshModeSuggestionAsync();
    }

    [RelayCommand]
    private async Task ClearLinkedTask()
    {
        await LinkTask(null);
    }

    /// <summary>
    /// Applies the suggested mode when idle (premium), or opens paywall when locked/free.
    /// </summary>
    [RelayCommand]
    private void ApplySuggestion()
    {
        if (ShowModeSuggestionLocked || _pendingModeSuggestion?.IsLocked == true)
        {
            var mi = T("Focus.ModeIntelligence", "Mode Intelligence");
            PaywallFeatureHint = mi;
            PremiumFeatureRequested?.Invoke(this, mi);
            return;
        }

        if (_pendingModeSuggestion == null)
            return;

        if (CurrentState is not (SessionState.Idle or SessionState.Completed))
            return;

        var mode = _pendingModeSuggestion.SuggestedMode;
        if (!EnsureModeAllowed(mode))
            return;

        PaywallFeatureHint = string.Empty;
        SelectedMode = mode;
        ApplySettingsToEngine(_cachedSettings);
        var duration = ResolveDurationSeconds(mode, _cachedSettings);
        _focusEngine.ConfigureSession(mode, duration, LinkedTaskId);
        UpdateTimerDisplay();
        UpdateCommandFlags();

        // Hide after apply; user already switched.
        _modeSuggestionDismissed = true;
        ClearModeSuggestionUi();
    }

    [RelayCommand]
    private void DismissSuggestion()
    {
        _modeSuggestionDismissed = true;
        ClearModeSuggestionUi();
    }

    /// <summary>
    /// Free-tier locked banner CTA — always routes to paywall for Mode Intelligence.
    /// </summary>
    [RelayCommand]
    private void UpgradeModeIntelligence()
    {
        var mi = T("Focus.ModeIntelligence", "Mode Intelligence");
        PaywallFeatureHint = mi;
        PremiumFeatureRequested?.Invoke(this, mi);
    }

    [RelayCommand]
    private async Task SaveJournalAsync()
    {
        if (PendingJournalSession == null)
            return;

        var rating = JournalEnergyRating is >= 1 and <= 5 ? JournalEnergyRating : (int?)null;
        await _sessionService.UpdateJournalAsync(
            PendingJournalSession.Id,
            string.IsNullOrWhiteSpace(JournalNoteDraft) ? null : JournalNoteDraft.Trim(),
            rating);

        PendingJournalSession.JournalNote = JournalNoteDraft;
        PendingJournalSession.EnergyRating = rating;
        DismissJournal();
    }

    [RelayCommand]
    private void DismissJournal()
    {
        PendingJournalSession = null;
        JournalNoteDraft = string.Empty;
        JournalEnergyRating = 0;
        ShowJournalPanel = false;
    }

    private async Task LoadAvailableTasksAsync()
    {
        var tasks = await _taskService.GetAllTasksAsync();
        var open = tasks.Where(t => !t.IsCompleted && t.ParentTaskId == null).Take(50);
        AvailableTasks = new ObservableCollection<TaskItem>(open);
    }

    private void OnEngineStateChanged(object? sender, SessionState newState)
    {
        var previous = _previousState;
        CurrentState = newState;
        IsOnBreak = _focusEngine.IsOnBreak || newState == SessionState.Break;
        StatusLabel = LocalizedState(newState);

        HandleFocusAssist(newState);
        HandleBreakNotifications(previous, newState);
        HandleSoundscape(previous, newState);

        _previousState = newState;
        UpdateCommandFlags();
        UpdateTimerDisplay();

        // Refresh suggestions when returning to idle/completed; hide while running.
        if (newState is SessionState.Idle or SessionState.Completed)
            _ = RefreshModeSuggestionAsync();
        else if (newState is SessionState.Running or SessionState.Break or SessionState.Paused)
            ClearModeSuggestionUi();
    }

    private async void HandleSoundscape(SessionState previous, SessionState newState)
    {
        if (_soundscapeCoordinator == null)
            return;

        try
        {
            var isOnBreak = _focusEngine.IsOnBreak || newState == SessionState.Break;
            await _soundscapeCoordinator.OnSessionStateChangedAsync(previous, newState, isOnBreak);
            await RefreshSoundscapeChipAsync();
        }
        catch
        {
            // Never break focus UX for audio failures.
        }
    }

    private async Task RefreshSoundscapeChipAsync()
    {
        if (_soundscapeCoordinator == null)
        {
            SoundscapeChipLabel = string.Empty;
            return;
        }

        try
        {
            if (!_cachedSettings.EnableSoundscapes)
            {
                SoundscapeChipLabel = string.Empty;
                return;
            }

            var name = await _soundscapeCoordinator.GetPreferredTrackDisplayNameAsync();
            SoundscapeChipLabel = string.IsNullOrEmpty(name)
                ? string.Empty
                : string.Format(T("Focus.SoundscapeChip", "Soundscape: {0}"), name);
        }
        catch
        {
            SoundscapeChipLabel = string.Empty;
        }
    }

    private string LocalizedState(SessionState state)
    {
        if (_localizer == null)
        {
            return state switch
            {
                SessionState.Idle => "Ready",
                SessionState.Running => "Focusing",
                SessionState.Paused => "Paused",
                SessionState.Break => "On break",
                SessionState.Completed => "Completed",
                _ => state.ToString()
            };
        }

        return state switch
        {
            SessionState.Idle => _localizer.GetString("Focus.Ready"),
            SessionState.Running => _localizer.GetString("Focus.Focusing"),
            SessionState.Paused => _localizer.GetString("Focus.Paused"),
            SessionState.Break => _localizer.GetString("Focus.OnBreak"),
            SessionState.Completed => _localizer.GetString("Focus.Completed"),
            _ => state.ToString()
        };
    }

    private void HandleFocusAssist(SessionState newState)
    {
        if (!_cachedSettings.EnableWindowsDoNotDisturbSync)
        {
            if (_focusAssistActive)
            {
                _focusAssistService.EndFocusSession();
                _focusAssistActive = false;
            }
            return;
        }

        if (newState == SessionState.Running && !_focusEngine.IsOnBreak)
        {
            if (!_focusAssistActive)
            {
                _focusAssistService.BeginFocusSession();
                _focusAssistActive = true;
            }
            return;
        }

        if (newState is SessionState.Idle or SessionState.Completed
            || newState == SessionState.Break
            || (newState == SessionState.Paused && _focusEngine.IsOnBreak))
        {
            if (newState is SessionState.Idle or SessionState.Completed or SessionState.Break)
            {
                if (_focusAssistActive)
                {
                    _focusAssistService.EndFocusSession();
                    _focusAssistActive = false;
                }
            }
        }
    }

    private void HandleBreakNotifications(SessionState previous, SessionState newState)
    {
        if (newState == SessionState.Break && previous != SessionState.Break && previous != SessionState.Paused)
        {
            var isLong = _focusEngine.CompletedFocusCount > 0
                && _cachedSettings.LongBreakInterval > 0
                && _focusEngine.CompletedFocusCount % _cachedSettings.LongBreakInterval == 0;
            _notificationService.ShowBreakStartedToast(isLong);
        }

        if (previous == SessionState.Break
            && newState is SessionState.Idle or SessionState.Running)
        {
            _notificationService.ShowBreakCompletedToast();
        }
    }

    private void OnEngineTick(object? sender, int elapsed) => UpdateTimerDisplay();

    private async void OnEngineSessionCompleted(object? sender, FocusSession session)
    {
        try
        {
            await _sessionService.SaveSessionAsync(session);
            var minutes = Math.Max(1, session.ElapsedSeconds / 60);
            LastCompletedMessage = string.Format(
                T("Focus.SessionSaved", "Saved {0} min {1} session"),
                minutes,
                ModeDisplayName(session.Mode));
            _notificationService.ShowSessionCompletedToast(session.Mode.ToString(), minutes);

            // Surface journaling after successful save.
            PendingJournalSession = session;
            JournalNoteDraft = session.JournalNote ?? string.Empty;
            JournalEnergyRating = session.EnergyRating ?? 0;
            ShowJournalPanel = true;

            // Best-effort local-first sync (no crash on failure).
            if (_syncService != null)
            {
                try { await _syncService.SyncNowAsync(); }
                catch { /* local-first */ }
            }
        }
        catch
        {
            LastCompletedMessage = T("Focus.SessionSaveFailed", "Session finished (save failed)");
        }

        // New history may unlock/change Mode Intelligence; allow a fresh banner.
        _modeSuggestionDismissed = false;
        await RefreshModeSuggestionAsync();

        UpdateTimerDisplay();
        UpdateCommandFlags();
    }

    /// <summary>
    /// Recomputes Mode Intelligence from the last 30 days of local sessions.
    /// </summary>
    public async Task RefreshModeSuggestionAsync()
    {
        if (_modeIntelligence == null)
        {
            ClearModeSuggestionUi();
            return;
        }

        if (_modeSuggestionDismissed)
        {
            ClearModeSuggestionUi();
            return;
        }

        if (CurrentState is not (SessionState.Idle or SessionState.Completed))
        {
            ClearModeSuggestionUi();
            return;
        }

        try
        {
            var utcNow = DateTime.UtcNow;
            var rangeStart = utcNow.AddDays(-ModeIntelligenceService.GlobalLookbackDays);
            var sessions = await _sessionService.GetSessionsInRangeAsync(rangeStart, utcNow.AddDays(1));

            string? taskEnergy = null;
            if (LinkedTaskId is Guid linkedId)
            {
                var linked = AvailableTasks.FirstOrDefault(t => t.Id == linkedId);
                if (linked != null && !string.IsNullOrWhiteSpace(linked.EnergyLevel))
                    taskEnergy = linked.EnergyLevel;
            }

            // Energy map across all tasks (open + completed) for energy-level aggregation.
            IReadOnlyDictionary<Guid, string>? energyMap = null;
            try
            {
                var allTasks = await _taskService.GetAllTasksAsync();
                energyMap = allTasks
                    .Where(t => !string.IsNullOrWhiteSpace(t.EnergyLevel))
                    .GroupBy(t => t.Id)
                    .ToDictionary(g => g.Key, g => g.First().EnergyLevel.Trim());

                if (taskEnergy == null && LinkedTaskId is Guid id)
                {
                    var t = allTasks.FirstOrDefault(x => x.Id == id);
                    if (t != null && !string.IsNullOrWhiteSpace(t.EnergyLevel))
                        taskEnergy = t.EnergyLevel;
                }
            }
            catch
            {
                energyMap = null;
            }

            var isPremium = _entitlements?.IsPremium == true;
            var suggestion = _modeIntelligence.Suggest(
                sessions,
                LinkedTaskId,
                taskEnergy,
                utcNow,
                isPremium,
                energyMap);

            if (suggestion == null)
            {
                ClearModeSuggestionUi();
                return;
            }

            _pendingModeSuggestion = suggestion;
            SuggestedModeLabel = ModeIntelligenceService.ModeDisplayName(suggestion.SuggestedMode);

            if (suggestion.IsLocked || !isPremium)
            {
                ShowModeSuggestion = false;
                ShowModeSuggestionLocked = true;
                SuggestionReason = T("Focus.ModeIntelligenceUpgrade", "Upgrade for Mode Intelligence");
            }
            else
            {
                ShowModeSuggestion = true;
                ShowModeSuggestionLocked = false;
                SuggestionReason = suggestion.Reason;
            }
        }
        catch
        {
            ClearModeSuggestionUi();
        }
    }

    private void ClearModeSuggestionUi()
    {
        ShowModeSuggestion = false;
        ShowModeSuggestionLocked = false;
        SuggestionReason = string.Empty;
        SuggestedModeLabel = string.Empty;
        _pendingModeSuggestion = null;
    }

    private void UpdateTimerDisplay()
    {
        // Stopwatch count-up; Flowtime can show count-up toward soft target when running.
        int secondsToDisplay;
        if (SelectedMode == FocusMode.Stopwatch && !_focusEngine.IsOnBreak)
            secondsToDisplay = _focusEngine.ElapsedSeconds;
        else if (SelectedMode == FocusMode.Flowtime && !_focusEngine.IsOnBreak
                 && _focusEngine.CurrentState is SessionState.Running or SessionState.Paused)
            secondsToDisplay = _focusEngine.ElapsedSeconds; // count-up toward soft target
        else
            secondsToDisplay = _focusEngine.RemainingSeconds;

        FormattedTime = FormatTime(secondsToDisplay);

        if (SelectedMode != FocusMode.Stopwatch && _focusEngine.TargetDurationSeconds > 0)
            ProgressRatio = Math.Clamp((double)_focusEngine.ElapsedSeconds / _focusEngine.TargetDurationSeconds, 0, 1);
        else
            ProgressRatio = 0;
    }

    private static string FormatTime(int totalSeconds)
    {
        totalSeconds = Math.Max(0, totalSeconds);
        var time = TimeSpan.FromSeconds(totalSeconds);
        if (time.TotalHours >= 1)
            return $"{(int)time.TotalHours}:{time.Minutes:D2}:{time.Seconds:D2}";
        return $"{(int)time.TotalMinutes:D2}:{time.Seconds:D2}";
    }

    private void UpdateCommandFlags()
    {
        var state = _focusEngine.CurrentState;
        IsOnBreak = _focusEngine.IsOnBreak || state == SessionState.Break;

        CanPause = state is SessionState.Running or SessionState.Break;
        CanSkip = IsOnBreak || state == SessionState.Break;
        CanStart = state is SessionState.Idle or SessionState.Paused or SessionState.Completed or SessionState.Break;
        if (state == SessionState.Running)
            CanStart = false;
    }
}
