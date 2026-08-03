using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using Pepinillo.Core.Models;
using Pepinillo.Core.Services;
using Pepinillo.Core.ViewModels;
using Xunit;

namespace Pepinillo.Core.Tests;

public class FocusViewModelTests
{
    private static FocusViewModel CreateVm(IFocusEngineService? engine = null)
    {
        engine ??= new FocusEngineService();
        return new FocusViewModel(
            engine,
            new FakeSettingsService(),
            new FakeSessionService(),
            new FakeTaskService(),
            new FakeNotificationService());
    }

    [Fact]
    public void InitialViewModel_ShouldHaveDefaultPomodoroTime()
    {
        using var engine = new FocusEngineService();
        var vm = CreateVm(engine);

        Assert.Equal("25:00", vm.FormattedTime);
        Assert.Equal(SessionState.Idle, vm.CurrentState);
        Assert.Equal(FocusMode.Pomodoro, vm.SelectedMode);
    }

    [Fact]
    public void SelectMode_Flowtime_ShouldUpdateFormattedTime()
    {
        using var engine = new FocusEngineService();
        var vm = CreateVm(engine);

        vm.SelectModeCommand.Execute(FocusMode.Flowtime);

        Assert.Equal(FocusMode.Flowtime, vm.SelectedMode);
        Assert.Equal("30:00", vm.FormattedTime);
    }

    private sealed class FakeSettingsService : ISettingsService
    {
        private UserSettings _settings = new();

        public Task<UserSettings> GetSettingsAsync() => Task.FromResult(_settings);
        public Task SaveSettingsAsync(UserSettings settings)
        {
            _settings = settings;
            return Task.CompletedTask;
        }
    }

    private sealed class FakeSessionService : IFocusSessionService
    {
        public List<FocusSession> Saved { get; } = new();

        public Task SaveSessionAsync(FocusSession session)
        {
            Saved.Add(session);
            return Task.CompletedTask;
        }

        public Task<List<FocusSession>> GetRecentSessionsAsync(int count = 20) =>
            Task.FromResult(new List<FocusSession>());

        public Task<int> GetTodayFocusMinutesAsync() => Task.FromResult(0);
    }

    private sealed class FakeTaskService : ITaskService
    {
        public Task<List<TaskItem>> GetAllTasksAsync() => Task.FromResult(new List<TaskItem>());
        public Task<List<TaskItem>> GetTodayTasksAsync() => Task.FromResult(new List<TaskItem>());
        public Task<List<TaskItem>> GetUpcomingTasksAsync() => Task.FromResult(new List<TaskItem>());
        public Task<List<TaskItem>> GetInboxTasksAsync() => Task.FromResult(new List<TaskItem>());
        public Task<TaskItem> CreateTaskAsync(string title, string? description = null, int estimatedMinutes = 25, DateTime? dueDate = null, Guid? parentTaskId = null) =>
            Task.FromResult(new TaskItem { Title = title });
        public Task<TaskItem?> UpdateTaskAsync(TaskItem task) => Task.FromResult<TaskItem?>(task);
        public Task ToggleTaskCompletionAsync(Guid taskId) => Task.CompletedTask;
        public Task DeleteTaskAsync(Guid taskId) => Task.CompletedTask;
    }

    private sealed class FakeNotificationService : INotificationService
    {
        public void ShowSessionCompletedToast(string sessionName, int durationMinutes) { }
        public void ShowBreakCompletedToast() { }
        public void ShowStreakMilestoneToast(int streakDays) { }
    }
}
