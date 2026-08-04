using System;
using System.Timers;
using Pepinillo.Core.Models;

namespace Pepinillo.Core.Services;

/// <summary>
/// Local focus timer engine. Pomodoro work/break cycles, Stopwatch, Flowtime soft target,
/// and Time Blocking fixed duration (no auto-break).
/// Session persistence is the caller's responsibility via <see cref="SessionCompleted"/>.
/// </summary>
public class FocusEngineService : IFocusEngineService, IDisposable
{
    private readonly System.Timers.Timer _timer;
    private SessionState _currentState = SessionState.Idle;
    private bool _inBreak;
    private int _shortBreakSeconds = 300;
    private int _longBreakSeconds = 900;
    private int _longBreakInterval = 4;
    private bool _autoStartBreaks;
    private bool _autoStartFocus;
    private int _workDurationSeconds = 1500;

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
    public bool IsOnBreak => _inBreak;
    public int CompletedFocusCount { get; private set; }
    public Guid? LinkedTaskId { get; private set; }

    public FocusEngineService()
    {
        _timer = new System.Timers.Timer(1000);
        _timer.Elapsed += OnTimerElapsed;
        _timer.AutoReset = true;
    }

    public void ApplyBreakSettings(
        int shortBreakSeconds,
        int longBreakSeconds,
        int longBreakInterval,
        bool autoStartBreaks,
        bool autoStartFocus)
    {
        _shortBreakSeconds = Math.Max(1, shortBreakSeconds);
        _longBreakSeconds = Math.Max(1, longBreakSeconds);
        _longBreakInterval = Math.Max(1, longBreakInterval);
        _autoStartBreaks = autoStartBreaks;
        _autoStartFocus = autoStartFocus;
    }

    public void ConfigureSession(FocusMode mode, int durationSeconds = 1500, Guid? taskId = null)
    {
        if (CurrentState is SessionState.Running or SessionState.Break)
            StopInternal(cancel: true);

        CurrentMode = mode;
        _workDurationSeconds = mode == FocusMode.Stopwatch ? 0 : Math.Max(0, durationSeconds);
        TargetDurationSeconds = _workDurationSeconds;
        ElapsedSeconds = 0;
        LinkedTaskId = taskId;
        _inBreak = false;

        CurrentSession = new FocusSession
        {
            Mode = mode,
            TargetDurationSeconds = TargetDurationSeconds,
            TaskItemId = taskId,
            StartedAt = DateTime.UtcNow
        };

        CurrentState = SessionState.Idle;
    }

    public void Start()
    {
        if (CurrentState == SessionState.Paused)
        {
            Resume();
            return;
        }

        if (CurrentState == SessionState.Break && _inBreak)
        {
            _timer.Start();
            return;
        }

        if (CurrentState is SessionState.Idle or SessionState.Completed)
        {
            _inBreak = false;
            TargetDurationSeconds = CurrentMode == FocusMode.Stopwatch ? 0 : _workDurationSeconds;

            CurrentSession ??= new FocusSession
            {
                Mode = CurrentMode,
                TargetDurationSeconds = TargetDurationSeconds,
                TaskItemId = LinkedTaskId,
                StartedAt = DateTime.UtcNow
            };

            CurrentSession.StartedAt = DateTime.UtcNow;
            CurrentSession.Mode = CurrentMode;
            CurrentSession.TargetDurationSeconds = TargetDurationSeconds;
            CurrentSession.TaskItemId = LinkedTaskId;

            CurrentState = SessionState.Running;
            _timer.Start();
        }
    }

    public void Pause()
    {
        if (CurrentState is SessionState.Running or SessionState.Break)
        {
            _timer.Stop();
            CurrentState = SessionState.Paused;
        }
    }

    public void Resume()
    {
        if (CurrentState != SessionState.Paused)
            return;

        CurrentState = _inBreak ? SessionState.Break : SessionState.Running;
        _timer.Start();
    }

    public void Stop() => StopInternal(cancel: false);

    public void SkipBreak()
    {
        if (!_inBreak && CurrentState != SessionState.Break)
            return;

        _timer.Stop();
        _inBreak = false;
        ElapsedSeconds = 0;
        PrepareNextWorkSession();

        // Auto-start next focus only for Pomodoro cycle.
        if (_autoStartFocus && CurrentMode == FocusMode.Pomodoro)
        {
            CurrentState = SessionState.Running;
            _timer.Start();
        }
        else
        {
            CurrentState = SessionState.Idle;
        }
    }

    private void StopInternal(bool cancel)
    {
        _timer.Stop();

        // Hybrid complete: Stopwatch always; Flowtime/TimeBlocking when user stops with progress.
        if (!cancel
            && !_inBreak
            && ElapsedSeconds > 0
            && CurrentSession != null
            && CurrentMode is FocusMode.Stopwatch or FocusMode.Flowtime or FocusMode.TimeBlocking)
        {
            CompleteCurrentWorkSession(fireCompleted: true, markEngineCompleted: false);
            ElapsedSeconds = 0;
            _inBreak = false;
            CurrentSession = null;
            TargetDurationSeconds = _workDurationSeconds;
            CurrentState = SessionState.Idle;
            return;
        }

        ElapsedSeconds = 0;
        _inBreak = false;
        CurrentSession = null;
        TargetDurationSeconds = _workDurationSeconds;
        CurrentState = SessionState.Idle;
    }

    private void OnTimerElapsed(object? sender, ElapsedEventArgs e)
    {
        ElapsedSeconds++;
        Tick?.Invoke(this, ElapsedSeconds);

        if (CurrentMode == FocusMode.Stopwatch)
            return;

        if (ElapsedSeconds < TargetDurationSeconds)
            return;

        _timer.Stop();

        if (_inBreak)
            CompleteBreakPhase();
        else
            CompleteWorkPhase();
    }

    private void CompleteWorkPhase()
    {
        CompleteCurrentWorkSession(fireCompleted: true, markEngineCompleted: true);
        CompletedFocusCount++;

        // Only Pomodoro enters an automatic break cycle.
        if (CurrentMode == FocusMode.Pomodoro)
        {
            EnterBreakPhase();
            return;
        }

        // Flowtime / TimeBlocking: session done, no auto-break.
        CurrentSession = null;
        ElapsedSeconds = 0;
        CurrentState = SessionState.Completed;
    }

    private void CompleteCurrentWorkSession(bool fireCompleted, bool markEngineCompleted)
    {
        if (CurrentSession == null)
            return;

        CurrentSession.ElapsedSeconds = ElapsedSeconds;
        CurrentSession.CompletedAt = DateTime.UtcNow;
        CurrentSession.IsCompleted = true;
        if (fireCompleted)
            SessionCompleted?.Invoke(this, CurrentSession);
        _ = markEngineCompleted;
    }

    private void EnterBreakPhase()
    {
        _inBreak = true;
        CurrentSession = null;
        ElapsedSeconds = 0;

        var useLong = CompletedFocusCount > 0 && CompletedFocusCount % _longBreakInterval == 0;
        TargetDurationSeconds = useLong ? _longBreakSeconds : _shortBreakSeconds;
        CurrentState = SessionState.Break;

        if (_autoStartBreaks)
            _timer.Start();
    }

    private void CompleteBreakPhase()
    {
        _inBreak = false;
        ElapsedSeconds = 0;
        PrepareNextWorkSession();

        if (_autoStartFocus)
        {
            CurrentState = SessionState.Running;
            _timer.Start();
        }
        else
        {
            CurrentState = SessionState.Idle;
        }
    }

    private void PrepareNextWorkSession()
    {
        TargetDurationSeconds = _workDurationSeconds > 0 ? _workDurationSeconds : 1500;
        CurrentSession = new FocusSession
        {
            Mode = CurrentMode,
            TargetDurationSeconds = TargetDurationSeconds,
            TaskItemId = LinkedTaskId,
            StartedAt = DateTime.UtcNow
        };
    }

    public void Dispose()
    {
        _timer.Stop();
        _timer.Dispose();
    }
}
