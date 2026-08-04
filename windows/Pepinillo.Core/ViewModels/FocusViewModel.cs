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
    private readonly ISyncService? _syncService;
    private readonly ILocalizationService? _localizer;
    private UserSettings _cachedSettings = new();
    private SessionState _previousState = SessionState.Idle;
    private bool _focusAssistActive;

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

    public FocusViewModel(
        IFocusEngineService focusEngine,
        ISettingsService settingsService,
        IFocusSessionService sessionService,
        ITaskService taskService,
        INotificationService notificationService,
        IFocusAssistService focusAssistService,
        ISyncService? syncService = null,
        ILocalizationService? localizer = null)
    {
        _focusEngine = focusEngine;
        _settingsService = settingsService;
        _sessionService = sessionService;
        _taskService = taskService;
        _notificationService = notificationService;
        _focusAssistService = focusAssistService;
        _syncService = syncService;
        _localizer = localizer;

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

        if (_focusEngine.CurrentState == SessionState.Idle && !_focusEngine.IsOnBreak)
        {
            var duration = ResolveDurationSeconds(SelectedMode, _cachedSettings);
            _focusEngine.ConfigureSession(SelectedMode, duration, LinkedTaskId);
            UpdateTimerDisplay();
        }

        await LoadAvailableTasksAsync();
        UpdateCommandFlags();
    }

    /// <summary>
    /// Reloads settings cache (e.g. after Settings page save) without resetting the engine mid-session.
    /// </summary>
    public async Task RefreshSettingsAsync()
    {
        _cachedSettings = await _settingsService.GetSettingsAsync();
        ApplySettingsToEngine(_cachedSettings);
        ApplyLanguage(_cachedSettings.PreferredLanguage);
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
    }

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
        ApplySettingsToEngine(_cachedSettings);

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

        SelectedMode = mode;
        ApplySettingsToEngine(_cachedSettings);
        var duration = ResolveDurationSeconds(mode, _cachedSettings);
        _focusEngine.ConfigureSession(mode, duration, LinkedTaskId);
        UpdateTimerDisplay();
        UpdateCommandFlags();
    }

    [RelayCommand]
    private void LinkTask(TaskItem? task)
    {
        if (CurrentState is not (SessionState.Idle or SessionState.Completed))
            return;

        LinkedTaskId = task?.Id;
        ActiveTaskTitle = task?.Title ?? "Free focus (no task linked)";

        var duration = ResolveDurationSeconds(SelectedMode, _cachedSettings);
        _focusEngine.ConfigureSession(SelectedMode, duration, LinkedTaskId);
    }

    [RelayCommand]
    private void ClearLinkedTask()
    {
        LinkTask(null);
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

        _previousState = newState;
        UpdateCommandFlags();
        UpdateTimerDisplay();
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
            LastCompletedMessage = $"Saved {minutes} min {session.Mode} session";
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
            LastCompletedMessage = "Session finished (save failed)";
        }

        UpdateTimerDisplay();
        UpdateCommandFlags();
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
