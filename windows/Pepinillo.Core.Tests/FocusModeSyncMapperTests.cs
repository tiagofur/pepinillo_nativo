using Pepinillo.Core.Models;
using Pepinillo.Core.Utilities;
using Xunit;

namespace Pepinillo.Core.Tests;

public class FocusModeSyncMapperTests
{
    [Theory]
    [InlineData(FocusMode.Pomodoro, "pomodoro")]
    [InlineData(FocusMode.Flowtime, "flowtime")]
    [InlineData(FocusMode.TimeBlocking, "timeblock")]
    [InlineData(FocusMode.Stopwatch, "stopwatch")]
    public void ToServer_MapsWindowsEnum(FocusMode mode, string expected)
    {
        Assert.Equal(expected, FocusModeSyncMapper.ToServer(mode));
    }

    [Theory]
    [InlineData("Pomodoro", "pomodoro")]
    [InlineData("Flow", "flowtime")]
    [InlineData("Flowtime", "flowtime")]
    [InlineData("Blocks", "timeblock")]
    [InlineData("TimeBlock", "timeblock")]
    [InlineData("time block", "timeblock")]
    [InlineData("timeblocking", "timeblock")]
    [InlineData("Chrono", "stopwatch")]
    [InlineData("Stopwatch", "stopwatch")]
    [InlineData("unknown", "pomodoro")]
    public void ToServer_MapsStringAliases(string local, string expected)
    {
        Assert.Equal(expected, FocusModeSyncMapper.ToServer(local));
    }

    [Theory]
    [InlineData("pomodoro", FocusMode.Pomodoro)]
    [InlineData("flowtime", FocusMode.Flowtime)]
    [InlineData("flow", FocusMode.Flowtime)]
    [InlineData("timeblock", FocusMode.TimeBlocking)]
    [InlineData("blocks", FocusMode.TimeBlocking)]
    [InlineData("time block", FocusMode.TimeBlocking)]
    [InlineData("stopwatch", FocusMode.Stopwatch)]
    [InlineData("chrono", FocusMode.Stopwatch)]
    [InlineData("unknown", FocusMode.Pomodoro)]
    public void ToLocal_MapsServerModes(string server, FocusMode expected)
    {
        Assert.Equal(expected, FocusModeSyncMapper.ToLocal(server));
    }

    [Fact]
    public void RoundTrip_WindowsModes()
    {
        foreach (FocusMode mode in new[]
                 {
                     FocusMode.Pomodoro, FocusMode.Flowtime, FocusMode.TimeBlocking, FocusMode.Stopwatch
                 })
        {
            var server = FocusModeSyncMapper.ToServer(mode);
            Assert.Equal(mode, FocusModeSyncMapper.ToLocal(server));
        }
    }
}
