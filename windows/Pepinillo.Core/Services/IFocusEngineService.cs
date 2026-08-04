using System;
using Pepinillo.Core.Models;

namespace Pepinillo.Core.Services;

public interface IFocusEngineService
{
    event EventHandler<SessionState>? StateChanged;
    event EventHandler<int>? Tick;
    event EventHandler<FocusSession>? SessionCompleted;

    SessionState CurrentState { get; }
    FocusMode CurrentMode { get; }
    int TargetDurationSeconds { get; }
    int ElapsedSeconds { get; }
    int RemainingSeconds { get; }
    FocusSession? CurrentSession { get; }
    bool IsOnBreak { get; }
    int CompletedFocusCount { get; }
    Guid? LinkedTaskId { get; }

    void ApplyBreakSettings(int shortBreakSeconds, int longBreakSeconds, int longBreakInterval, bool autoStartBreaks, bool autoStartFocus);
    void ConfigureSession(FocusMode mode, int durationSeconds = 1500, Guid? taskId = null);
    void Start();
    void Pause();
    void Resume();
    void Stop();
    void SkipBreak();
}
