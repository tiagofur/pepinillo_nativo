using System;
using System.Threading;
using System.Threading.Tasks;
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

        // Drive one tick completion via short timer wait
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

        // Force elapsed without waiting full second by using reflection-free approach:
        // wait for at least one tick
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
}
