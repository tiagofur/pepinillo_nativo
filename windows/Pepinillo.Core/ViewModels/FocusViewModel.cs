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
    private UserSettings _cachedSettings = new();

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

    public FocusViewModel(
        IFocusEngineService focusEngine,
        ISettingsService settingsService,
        IFocusSessionService sessionService,
        ITaskService taskService,
        INotificationService notificationService)
    {
        _focusEngine = focusEngine;
        _settingsService = settingsService;
        _sessionService = sessionService;
        _taskService = taskService;
        _notificationService = notificationService;

        _focusEngine.StateChanged += OnEngineStateChanged;
        _focusEngine.Tick += OnEngineTick;
        _focusEngine.SessionCompleted += OnEngineSessionCompleted;

        UpdateTimerDisplay();
        UpdateCommandFlags();
    }

    public async Task InitializeAsync()
    {
        _cachedSettings = await _settingsService.GetSettingsAsync();
        ApplySettingsToEngine(_cachedSettings);

        if (_focusEngine.CurrentState == SessionState.Idle && !_focusEngine.IsOnBreak)
        {
            var duration = ResolveDurationSeconds(SelectedMode, _cachedSettings);
            _focusEngine.ConfigureSession(SelectedMode, duration, LinkedTaskId);
            UpdateTimerDisplay();
        }

        await LoadAvailableTasksAsync();
        UpdateCommandFlags();
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
        FocusMode.TimeBlocking => 3600,
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

    private async Task LoadAvailableTasksAsync()
    {
        var tasks = await _taskService.GetAllTasksAsync();
        var open = tasks.Where(t => !t.IsCompleted && t.ParentTaskId == null).Take(50);
        AvailableTasks = new ObservableCollection<TaskItem>(open);
    }

    private void OnEngineStateChanged(object? sender, SessionState newState)
    {
        CurrentState = newState;
        IsOnBreak = _focusEngine.IsOnBreak || newState == SessionState.Break;
        StatusLabel = newState switch
        {
            SessionState.Idle => "Ready",
            SessionState.Running => "Focusing",
            SessionState.Paused => "Paused",
            SessionState.Break => "On break",
            SessionState.Completed => "Completed",
            _ => newState.ToString()
        };
        UpdateCommandFlags();
        UpdateTimerDisplay();
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
        int secondsToDisplay = SelectedMode == FocusMode.Stopwatch && !_focusEngine.IsOnBreak
            ? _focusEngine.ElapsedSeconds
            : _focusEngine.RemainingSeconds;

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
