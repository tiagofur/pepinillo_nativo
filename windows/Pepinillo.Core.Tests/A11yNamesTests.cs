using System.Linq;
using System.Reflection;
using Pepinillo.Core.Accessibility;
using Xunit;

namespace Pepinillo.Core.Tests;

public class A11yNamesTests
{
    [Fact]
    public void AllPublicConstants_AreNonEmptyEnglishNames()
    {
        var fields = typeof(A11yNames)
            .GetFields(BindingFlags.Public | BindingFlags.Static | BindingFlags.FlattenHierarchy)
            .Where(f => f.IsLiteral && !f.IsInitOnly && f.FieldType == typeof(string))
            .ToList();

        Assert.NotEmpty(fields);
        Assert.True(fields.Count >= 40, $"Expected a full primary-surface catalog, got {fields.Count}");

        foreach (var field in fields)
        {
            var value = (string)field.GetRawConstantValue()!;
            Assert.False(string.IsNullOrWhiteSpace(value), $"{field.Name} is empty");
            Assert.DoesNotContain('\t', value);
            Assert.DoesNotContain('\n', value);
        }
    }

    [Fact]
    public void CriticalFocusAndPaywallNames_MatchIssueSpec()
    {
        Assert.Equal("Select Pomodoro mode", A11yNames.FocusModePomodoro);
        Assert.Equal("Start or resume focus session", A11yNames.FocusStart);
        Assert.Equal("Pause focus session", A11yNames.FocusPause);
        Assert.Equal("Session timer", A11yNames.FocusTimerDisplay);
        Assert.Equal("Buy Pepinillo Plus", A11yNames.PaywallBuyPlus);
        Assert.Equal("Restore purchases", A11yNames.PaywallRestore);
        Assert.Equal("Mini timer elapsed", A11yNames.MiniTimerElapsed);
        Assert.Equal("Add your first task", A11yNames.TasksEmptyCta);
    }
}
