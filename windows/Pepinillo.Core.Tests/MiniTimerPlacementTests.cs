using Pepinillo.Core.Utilities;
using Xunit;

namespace Pepinillo.Core.Tests;

public class MiniTimerPlacementTests
{
    [Fact]
    public void FromPersisted_NullPosition_ReturnsNull()
    {
        Assert.Null(MiniTimerPlacement.FromPersisted(null, null, 320, 120));
        Assert.Null(MiniTimerPlacement.FromPersisted(10, null, 320, 120));
        Assert.Null(MiniTimerPlacement.FromPersisted(null, 20, 320, 120));
    }

    [Fact]
    public void FromPersisted_AppliesDefaultsAndClampsSize()
    {
        var rect = MiniTimerPlacement.FromPersisted(100, 200, null, null);
        Assert.NotNull(rect);
        Assert.Equal(100, rect!.Value.X);
        Assert.Equal(200, rect.Value.Y);
        Assert.Equal(MiniTimerPlacement.DefaultWidth, rect.Value.Width);
        Assert.Equal(MiniTimerPlacement.DefaultHeight, rect.Value.Height);

        var tiny = MiniTimerPlacement.FromPersisted(0, 0, 10, 10)!;
        Assert.Equal(MiniTimerPlacement.MinWidth, tiny.Value.Width);
        Assert.Equal(MiniTimerPlacement.MinHeight, tiny.Value.Height);

        var huge = MiniTimerPlacement.FromPersisted(0, 0, 9999, 9999)!;
        Assert.Equal(MiniTimerPlacement.MaxWidth, huge.Value.Width);
        Assert.Equal(MiniTimerPlacement.MaxHeight, huge.Value.Height);
    }

    [Fact]
    public void IsReasonablyOnScreen_FalseWhenCompletelyOff()
    {
        var window = new MiniTimerPlacement.Rect(5000, 5000, 320, 120);
        var work = new MiniTimerPlacement.WorkArea(0, 0, 1920, 1080);
        Assert.False(MiniTimerPlacement.IsReasonablyOnScreen(window, work));
    }

    [Fact]
    public void IsReasonablyOnScreen_TrueWhenCentered()
    {
        var window = new MiniTimerPlacement.Rect(100, 100, 320, 120);
        var work = new MiniTimerPlacement.WorkArea(0, 0, 1920, 1080);
        Assert.True(MiniTimerPlacement.IsReasonablyOnScreen(window, work));
    }

    [Fact]
    public void ClampToWorkArea_PullsOffScreenOntoPrimary()
    {
        var window = new MiniTimerPlacement.Rect(9000, 9000, 320, 120);
        var work = new MiniTimerPlacement.WorkArea(0, 0, 1920, 1080);
        var clamped = MiniTimerPlacement.ClampToWorkArea(window, work);

        Assert.True(clamped.X >= work.X);
        Assert.True(clamped.Y >= work.Y);
        Assert.True(clamped.X + clamped.Width <= work.X + work.Width);
        Assert.True(clamped.Y + clamped.Height <= work.Y + work.Height);
    }

    [Fact]
    public void EnsureVisible_ClampsWhenOffScreen_KeepsWhenOnScreen()
    {
        var work = new MiniTimerPlacement.WorkArea(0, 0, 1920, 1080);
        var on = new MiniTimerPlacement.Rect(40, 40, 320, 120);
        var ensuredOn = MiniTimerPlacement.EnsureVisible(on, work);
        Assert.Equal(40, ensuredOn.X);
        Assert.Equal(40, ensuredOn.Y);

        var off = new MiniTimerPlacement.Rect(-2000, -2000, 320, 120);
        var ensuredOff = MiniTimerPlacement.EnsureVisible(off, work);
        Assert.True(MiniTimerPlacement.IsReasonablyOnScreen(ensuredOff, work));
    }
}
