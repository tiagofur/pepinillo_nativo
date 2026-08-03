using Pepinillo.Core.Models;
using Pepinillo.Core.Services;
using Pepinillo.Core.ViewModels;
using Xunit;

namespace Pepinillo.Core.Tests;

public class FocusViewModelTests
{
    [Fact]
    public void InitialViewModel_ShouldHaveDefaultPomodoroTime()
    {
        using var engine = new FocusEngineService();
        var vm = new FocusViewModel(engine);

        Assert.Equal("25:00", vm.FormattedTime);
        Assert.Equal(SessionState.Idle, vm.CurrentState);
        Assert.Equal(FocusMode.Pomodoro, vm.SelectedMode);
    }

    [Fact]
    public void SelectMode_Flowtime_ShouldUpdateFormattedTime()
    {
        using var engine = new FocusEngineService();
        var vm = new FocusViewModel(engine);

        vm.SelectModeCommand.Execute(FocusMode.Flowtime);

        Assert.Equal(FocusMode.Flowtime, vm.SelectedMode);
        Assert.Equal("30:00", vm.FormattedTime);
    }
}
