using Pepinillo.Core.Utilities;
using Xunit;

namespace Pepinillo.Core.Tests;

public class HotkeyChordParserTests
{
    [Theory]
    [InlineData("Win+Shift+P", true, true, false, false, 'P')]
    [InlineData("win+shift+s", true, true, false, false, 'S')]
    [InlineData("Ctrl+Alt+1", false, false, true, true, '1')]
    [InlineData("Meta+M", true, false, false, false, 'M')]
    [InlineData("Windows+Control+A", true, false, true, false, 'A')]
    public void TryParse_ValidChords_Succeeds(
        string input,
        bool win,
        bool shift,
        bool ctrl,
        bool alt,
        char key)
    {
        Assert.True(HotkeyChordParser.TryParse(input, out var chord));
        Assert.Equal(win, chord.Win);
        Assert.Equal(shift, chord.Shift);
        Assert.Equal(ctrl, chord.Ctrl);
        Assert.Equal(alt, chord.Alt);
        Assert.Equal(key, chord.Key);
    }

    [Theory]
    [InlineData(null)]
    [InlineData("")]
    [InlineData("   ")]
    [InlineData("P")]
    [InlineData("Win+")]
    [InlineData("Win+Shift")]
    [InlineData("Shift+P+Q")]
    [InlineData("Win+F1")]
    [InlineData("++P")]
    public void TryParse_InvalidChords_Fails(string? input)
    {
        Assert.False(HotkeyChordParser.TryParse(input, out _));
    }

    [Fact]
    public void Format_RoundTripsNormalizedString()
    {
        Assert.True(HotkeyChordParser.TryParse("win+shift+p", out var chord));
        Assert.Equal("Win+Shift+P", chord.Format());
    }

    [Fact]
    public void NormalizeOrDefault_FallsBackOnInvalid()
    {
        Assert.Equal(
            HotkeyChordParser.DefaultPlayPause,
            HotkeyChordParser.NormalizeOrDefault("nope", HotkeyChordParser.DefaultPlayPause));
        Assert.Equal(
            "Win+Shift+S",
            HotkeyChordParser.NormalizeOrDefault("Win+Shift+S", HotkeyChordParser.DefaultSkip));
    }

    [Fact]
    public void Defaults_AreValid()
    {
        Assert.True(HotkeyChordParser.IsValid(HotkeyChordParser.DefaultPlayPause));
        Assert.True(HotkeyChordParser.IsValid(HotkeyChordParser.DefaultSkip));
        Assert.True(HotkeyChordParser.IsValid(HotkeyChordParser.DefaultMiniTimer));
    }
}
