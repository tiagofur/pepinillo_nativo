using System;
using System.Threading.Tasks;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using Pepinillo.Core.Models;
using Pepinillo.Core.Services;

namespace Pepinillo.Core.ViewModels;

public partial class FocusViewModel : ObservableObject
{
    private readonly IFocusEngineService _focusEngine;

    [ObservableProperty]
    private SessionState _currentState = SessionState.Idle;

    [ObservableProperty]
    private FocusMode _selectedMode = FocusMode.Pomodoro;

    [ObservableProperty]
    private string _formattedTime = "25:00";

    [ObservableProperty]
    private double _progressRatio = 0.0;

    [ObservableProperty]
    private string _activeTaskTitle = "Selecciona una tarea o enfócate libremente";

    public FocusViewModel(IFocusEngineService focusEngine)
    {
        _focusEngine = focusEngine;
        _focusEngine.StateChanged += OnEngineStateChanged;
        _focusEngine.Tick += OnEngineTick;
        _focusEngine.SessionCompleted += OnEngineSessionCompleted;

        UpdateTimerDisplay();
    }

    [RelayCommand]
    private void StartSession()
    {
        if (CurrentState == SessionState.Idle)
        {
            _focusEngine.ConfigureSession(SelectedMode);
            _focusEngine.Start();
        }
        else if (CurrentState == SessionState.Paused)
        {
            _focusEngine.Resume();
        }
    }

    [RelayCommand]
    private void PauseSession()
    {
        if (CurrentState == SessionState.Running)
        {
            _focusEngine.Pause();
        }
    }

    [RelayCommand]
    private void StopSession()
    {
        _focusEngine.Stop();
        UpdateTimerDisplay();
    }

    [RelayCommand]
    private void SelectMode(FocusMode mode)
    {
        if (CurrentState == SessionState.Idle)
        {
            SelectedMode = mode;
            int defaultDuration = mode switch
            {
                FocusMode.Pomodoro => 1500,
                FocusMode.Stopwatch => 0,
                FocusMode.Flowtime => 1800,
                FocusMode.TimeBlocking => 3600,
                _ => 1500
            };

            _focusEngine.ConfigureSession(mode, defaultDuration);
            UpdateTimerDisplay();
        }
    }

    private void OnEngineStateChanged(object? sender, SessionState newState)
    {
        CurrentState = newState;
    }

    private void OnEngineTick(object? sender, int elapsed)
    {
        UpdateTimerDisplay();
    }

    private void OnEngineSessionCompleted(object? sender, FocusSession session)
    {
        UpdateTimerDisplay();
    }

    private void UpdateTimerDisplay()
    {
        int secondsToDisplay = SelectedMode == FocusMode.Stopwatch
            ? _focusEngine.ElapsedSeconds
            : _focusEngine.RemainingSeconds;

        TimeSpan time = TimeSpan.FromSeconds(secondsToDisplay);
        FormattedTime = $"{time.Minutes:D2}:{time.Seconds:D2}";

        if (SelectedMode != FocusMode.Stopwatch && _focusEngine.TargetDurationSeconds > 0)
        {
            ProgressRatio = (double)_focusEngine.ElapsedSeconds / _focusEngine.TargetDurationSeconds;
        }
        else
        {
            ProgressRatio = 0.0;
        }
    }
}
