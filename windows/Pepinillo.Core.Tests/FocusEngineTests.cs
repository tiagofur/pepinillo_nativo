using System;
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
}
