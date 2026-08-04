using System;
using System.Threading;
using Pepinillo.Core.Models;
using Pepinillo.Core.Services;
using Xunit;

namespace Pepinillo.Core.Tests;

public class FocusEngineTests
{
    [Fact]
    public void InitialState_ShouldBeIdle()
    {
        using var engine = new FocusEngineService();
        Assert.Equal(SessionState.Idle, engine.CurrentState);
        Assert.Equal(0, engine.ElapsedSeconds);
    }

    [Fact]
    public void ConfigureSession_ShouldSetModeAndDuration()
    {
        using var engine = new FocusEngineService();
        engine.ConfigureSession(FocusMode.Flowtime, 3600);

        Assert.Equal(FocusMode.Flowtime, engine.CurrentMode);
        Assert.Equal(3600, engine.TargetDurationSeconds);
        Assert.Equal(3600, engine.RemainingSeconds);
    }

    [Fact]
    public void StartAndPause_ShouldUpdateStateCorrectly()
    {
        using var engine = new FocusEngineService();
        engine.ConfigureSession(FocusMode.Pomodoro, 1500);

        engine.Start();
        Assert.Equal(SessionState.Running, engine.CurrentState);

        engine.Pause();
        Assert.Equal(SessionState.Paused, engine.CurrentState);

        engine.Resume();
        Assert.Equal(SessionState.Running, engine.CurrentState);

        engine.Stop();
        Assert.Equal(SessionState.Idle, engine.CurrentState);
    }

    [Fact]
    public void Pomodoro_WorkComplete_ShouldEnterBreak_AndFireSessionCompleted()
    {
        using var engine = new FocusEngineService();
        engine.ApplyBreakSettings(
            shortBreakSeconds: 5,
            longBreakSeconds: 10,
            longBreakInterval: 4,
            autoStartBreaks: false,
            autoStartFocus: false);

        FocusSession? completed = null;
        engine.SessionCompleted += (_, s) => completed = s;

        engine.ConfigureSession(FocusMode.Pomodoro, durationSeconds: 1, taskId: Guid.NewGuid());
        engine.Start();

        var deadline = DateTime.UtcNow.AddSeconds(3);
        while (engine.CurrentState != SessionState.Break && DateTime.UtcNow < deadline)
            Thread.Sleep(50);

        Assert.Equal(SessionState.Break, engine.CurrentState);
        Assert.True(engine.IsOnBreak);
        Assert.NotNull(completed);
        Assert.True(completed!.IsCompleted);
        Assert.Equal(1, completed.ElapsedSeconds);
        Assert.NotNull(completed.TaskItemId);
    }

    [Fact]
    public void SkipBreak_ShouldReturnToIdle()
    {
        using var engine = new FocusEngineService();
        engine.ApplyBreakSettings(5, 10, 4, autoStartBreaks: true, autoStartFocus: false);
        engine.ConfigureSession(FocusMode.Pomodoro, 1);
        engine.Start();

        var deadline = DateTime.UtcNow.AddSeconds(3);
        while (engine.CurrentState != SessionState.Break && DateTime.UtcNow < deadline)
            Thread.Sleep(50);

        engine.SkipBreak();
        Assert.Equal(SessionState.Idle, engine.CurrentState);
        Assert.False(engine.IsOnBreak);
    }

    [Fact]
    public void Stopwatch_Stop_ShouldCompleteSession()
    {
        using var engine = new FocusEngineService();
        FocusSession? completed = null;
        engine.SessionCompleted += (_, s) => completed = s;

        engine.ConfigureSession(FocusMode.Stopwatch, 0);
        engine.Start();

        var deadline = DateTime.UtcNow.AddSeconds(3);
        while (engine.ElapsedSeconds < 1 && DateTime.UtcNow < deadline)
            Thread.Sleep(50);

        Assert.True(engine.ElapsedSeconds >= 1);
        engine.Stop();

        Assert.Equal(SessionState.Idle, engine.CurrentState);
        Assert.NotNull(completed);
        Assert.True(completed!.IsCompleted);
        Assert.True(completed.ElapsedSeconds >= 1);
    }

    [Fact]
    public void Flowtime_PastSoftTarget_ShouldKeepRunning_UntilStop()
    {
        using var engine = new FocusEngineService();
        engine.ApplyBreakSettings(5, 10, 4, autoStartBreaks: true, autoStartFocus: true);

        FocusSession? completed = null;
        engine.SessionCompleted += (_, s) => completed = s;

        engine.ConfigureSession(FocusMode.Flowtime, durationSeconds: 1);
        engine.Start();

        var deadline = DateTime.UtcNow.AddSeconds(4);
        while (engine.ElapsedSeconds < 2 && DateTime.UtcNow < deadline)
            Thread.Sleep(50);

        // Soft target: still running past 1s goal.
        Assert.Equal(SessionState.Running, engine.CurrentState);
        Assert.True(engine.ElapsedSeconds >= 2);
        Assert.Null(completed);

        engine.Stop();
        Assert.NotNull(completed);
        Assert.True(completed!.IsCompleted);
        Assert.True(completed.ElapsedSeconds >= 2);
        Assert.Equal(FocusMode.Flowtime, completed.Mode);
        Assert.Equal(SessionState.Idle, engine.CurrentState);
    }

    [Fact]
    public void Flowtime_EarlyStop_ShouldCompleteSession()
    {
        using var engine = new FocusEngineService();
        FocusSession? completed = null;
        engine.SessionCompleted += (_, s) => completed = s;

        engine.ConfigureSession(FocusMode.Flowtime, durationSeconds: 600);
        engine.Start();

        var deadline = DateTime.UtcNow.AddSeconds(3);
        while (engine.ElapsedSeconds < 1 && DateTime.UtcNow < deadline)
            Thread.Sleep(50);

        engine.Stop();
        Assert.NotNull(completed);
        Assert.True(completed!.IsCompleted);
        Assert.True(completed.ElapsedSeconds >= 1);
        Assert.Equal(SessionState.Idle, engine.CurrentState);
    }

    [Fact]
    public void TimeBlocking_TargetHit_ShouldComplete_WithoutBreak()
    {
        using var engine = new FocusEngineService();
        engine.ApplyBreakSettings(5, 10, 4, autoStartBreaks: true, autoStartFocus: true);

        FocusSession? completed = null;
        engine.SessionCompleted += (_, s) => completed = s;

        engine.ConfigureSession(FocusMode.TimeBlocking, durationSeconds: 1);
        engine.Start();

        var deadline = DateTime.UtcNow.AddSeconds(3);
        while (engine.CurrentState != SessionState.Completed && DateTime.UtcNow < deadline)
            Thread.Sleep(50);

        Assert.Equal(SessionState.Completed, engine.CurrentState);
        Assert.False(engine.IsOnBreak);
        Assert.NotNull(completed);
        Assert.Equal(FocusMode.TimeBlocking, completed!.Mode);
    }

    [Fact]
    public void TimeBlocking_EarlyStop_ShouldCompleteSession()
    {
        using var engine = new FocusEngineService();
        FocusSession? completed = null;
        engine.SessionCompleted += (_, s) => completed = s;

        engine.ConfigureSession(FocusMode.TimeBlocking, durationSeconds: 3600);
        engine.Start();

        var deadline = DateTime.UtcNow.AddSeconds(3);
        while (engine.ElapsedSeconds < 1 && DateTime.UtcNow < deadline)
            Thread.Sleep(50);

        engine.Stop();
        Assert.NotNull(completed);
        Assert.True(completed!.IsCompleted);
    }

    [Fact]
    public void Pomodoro_StopMidWork_ShouldCompletePartialSession()
    {
        using var engine = new FocusEngineService();
        FocusSession? completed = null;
        engine.SessionCompleted += (_, s) => completed = s;

        engine.ConfigureSession(FocusMode.Pomodoro, durationSeconds: 600);
        engine.Start();

        var deadline = DateTime.UtcNow.AddSeconds(3);
        while (engine.ElapsedSeconds < 1 && DateTime.UtcNow < deadline)
            Thread.Sleep(50);

        engine.Stop();

        Assert.Equal(SessionState.Idle, engine.CurrentState);
        Assert.NotNull(completed);
        Assert.True(completed!.IsCompleted);
        Assert.True(completed.ElapsedSeconds >= 1);
        Assert.Equal(FocusMode.Pomodoro, completed.Mode);
        Assert.False(engine.IsOnBreak);
    }

    [Fact]
    public void Pomodoro_Reconfigure_ShouldNotCompletePartialSession()
    {
        using var engine = new FocusEngineService();
        FocusSession? completed = null;
        engine.SessionCompleted += (_, s) => completed = s;

        engine.ConfigureSession(FocusMode.Pomodoro, durationSeconds: 600);
        engine.Start();

        var deadline = DateTime.UtcNow.AddSeconds(3);
        while (engine.ElapsedSeconds < 1 && DateTime.UtcNow < deadline)
            Thread.Sleep(50);

        // Mode switch cancels without saving.
        engine.ConfigureSession(FocusMode.Stopwatch, 0);
        Assert.Null(completed);
        Assert.Equal(SessionState.Idle, engine.CurrentState);
    }
}
