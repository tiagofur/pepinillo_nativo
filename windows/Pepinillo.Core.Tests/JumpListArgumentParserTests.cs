using Pepinillo.Core.Utilities;
using Xunit;

namespace Pepinillo.Core.Tests;

public class JumpListArgumentParserTests
{
    [Theory]
    [InlineData(null, JumpListAction.None)]
    [InlineData("", JumpListAction.None)]
    [InlineData("   ", JumpListAction.None)]
    [InlineData("unknown", JumpListAction.None)]
    [InlineData("action=nope", JumpListAction.None)]
    public void Parse_UnknownOrEmpty_ReturnsNone(string? input, JumpListAction expected)
    {
        Assert.Equal(expected, JumpListArgumentParser.Parse(input));
    }

    [Theory]
    [InlineData("action=pomodoro", JumpListAction.Pomodoro)]
    [InlineData("ACTION=POMODORO", JumpListAction.Pomodoro)]
    [InlineData("pomodoro", JumpListAction.Pomodoro)]
    [InlineData("start", JumpListAction.Pomodoro)]
    [InlineData("focus", JumpListAction.Pomodoro)]
    [InlineData("action=tasks", JumpListAction.Tasks)]
    [InlineData("tasks", JumpListAction.Tasks)]
    [InlineData("task", JumpListAction.Tasks)]
    [InlineData("action=pause", JumpListAction.Pause)]
    [InlineData("pause", JumpListAction.Pause)]
    [InlineData("resume", JumpListAction.Pause)]
    [InlineData("playpause", JumpListAction.Pause)]
    [InlineData("toggle", JumpListAction.Pause)]
    [InlineData("action=mini", JumpListAction.Mini)]
    [InlineData("mini", JumpListAction.Mini)]
    [InlineData("mini-timer", JumpListAction.Mini)]
    [InlineData("minitimer", JumpListAction.Mini)]
    public void Parse_KnownTokens_MapsAction(string input, JumpListAction expected)
    {
        Assert.Equal(expected, JumpListArgumentParser.Parse(input));
    }

    [Fact]
    public void Parse_FindsActionPairAmongTokens()
    {
        Assert.Equal(JumpListAction.Tasks, JumpListArgumentParser.Parse("foo action=tasks bar"));
        Assert.Equal(JumpListAction.Pause, JumpListArgumentParser.Parse("noise&action=pause"));
    }

    [Fact]
    public void Constants_MatchCanonicalArguments()
    {
        Assert.Equal(JumpListAction.Pomodoro, JumpListArgumentParser.Parse(JumpListArgumentParser.ActionPomodoro));
        Assert.Equal(JumpListAction.Tasks, JumpListArgumentParser.Parse(JumpListArgumentParser.ActionTasks));
        Assert.Equal(JumpListAction.Pause, JumpListArgumentParser.Parse(JumpListArgumentParser.ActionPause));
        Assert.Equal(JumpListAction.Mini, JumpListArgumentParser.Parse(JumpListArgumentParser.ActionMini));
    }
}
