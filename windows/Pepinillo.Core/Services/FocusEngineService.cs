using System;
using System.Timers;
using Pepinillo.Core.Models;

namespace Pepinillo.Core.Services;

public class FocusEngineService : IFocusEngineService, IDisposable
{
    private readonly System.Timers.Timer _timer;
    private SessionState _currentState = SessionState.Idle;

    public event EventHandler<SessionState>? StateChanged;
    public event EventHandler<int>? Tick;
    public event EventHandler<FocusSession>? SessionCompleted;

    public SessionState CurrentState
    {
        get => _currentState;
        private set
        {
            if (_currentState != value)
            {
                _currentState = value;
                StateChanged?.Invoke(this, _currentState);
            }
        }
    }

    public FocusMode CurrentMode { get; private set; } = FocusMode.Pomodoro;
    public int TargetDurationSeconds { get; private set; } = 1500;
    public int ElapsedSeconds { get; private set; }
    public int RemainingSeconds => Math.Max(0, TargetDurationSeconds - ElapsedSeconds);
    public FocusSession? CurrentSession { get; private set; }

    public FocusEngineService()
    {
        _timer = new System.Timers.Timer(1000);
        _timer.Elapsed += OnTimerElapsed;
    }

    public void ConfigureSession(FocusMode mode, int durationSeconds = 1500, Guid? taskId = null)
    {
        if (CurrentState == SessionState.Running)
        {
            Stop();
        }

        CurrentMode = mode;
        TargetDurationSeconds = durationSeconds;
        ElapsedSeconds = 0;

        CurrentSession = new FocusSession
        {
            Mode = mode,
            TargetDurationSeconds = durationSeconds,
            TaskItemId = taskId,
            StartedAt = DateTime.UtcNow
        };

        CurrentState = SessionState.Idle;
    }

    public void Start()
    {
        if (CurrentState == SessionState.Idle || CurrentState == SessionState.Paused)
        {
            CurrentSession ??= new FocusSession
            {
                Mode = CurrentMode,
                TargetDurationSeconds = TargetDurationSeconds,
                StartedAt = DateTime.UtcNow
            };

            CurrentState = SessionState.Running;
            _timer.Start();
        }
    }

    public void Pause()
    {
        if (CurrentState == SessionState.Running)
        {
            _timer.Stop();
            CurrentState = SessionState.Paused;
        }
    }

    public void Resume()
    {
        if (CurrentState == SessionState.Paused)
        {
            CurrentState = SessionState.Running;
            _timer.Start();
        }
    }

    public void Stop()
    {
        _timer.Stop();
        ElapsedSeconds = 0;
        CurrentState = SessionState.Idle;
    }

    public void SkipBreak()
    {
        if (CurrentState == SessionState.Break)
        {
            _timer.Stop();
            CurrentState = SessionState.Idle;
        }
    }

    private void OnTimerElapsed(object? sender, ElapsedEventArgs e)
    {
        ElapsedSeconds++;
        Tick?.Invoke(this, ElapsedSeconds);

        if (CurrentMode != FocusMode.Stopwatch && ElapsedSeconds >= TargetDurationSeconds)
        {
            _timer.Stop();
            if (CurrentSession != null)
            {
                CurrentSession.ElapsedSeconds = ElapsedSeconds;
                CurrentSession.CompletedAt = DateTime.UtcNow;
                CurrentSession.IsCompleted = true;
            }

            CurrentState = SessionState.Completed;
            SessionCompleted?.Invoke(this, CurrentSession!);
        }
    }

    public void Dispose()
    {
        _timer.Stop();
        _timer.Dispose();
    }
}
