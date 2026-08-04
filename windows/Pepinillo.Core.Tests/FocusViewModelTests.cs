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
    private static FocusViewModel CreateVm(IFocusEngineService? engine = null, FakeSessionService? sessions = null)
    {
        engine ??= new FocusEngineService();
        sessions ??= new FakeSessionService();
        return new FocusViewModel(
            engine,
            new FakeSettingsService(),
            sessions,
            new FakeTaskService(),
            new FakeNotificationService(),
            new FakeFocusAssistService());
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
        // Idle Flowtime shows remaining soft target (count-up only while running).
        Assert.Equal("30:00", vm.FormattedTime);
        Assert.Equal(1800, engine.TargetDurationSeconds);
    }

    [Fact]
    public void SelectMode_TimeBlocking_ShouldUseSixtyMinutesDefault()
    {
        using var engine = new FocusEngineService();
        var vm = CreateVm(engine);

        vm.SelectModeCommand.Execute(FocusMode.TimeBlocking);

        Assert.Equal(FocusMode.TimeBlocking, vm.SelectedMode);
        Assert.Equal(3600, engine.TargetDurationSeconds);
        Assert.Equal("1:00:00", vm.FormattedTime);
    }

    [Fact]
    public async Task SaveJournal_ShouldPersistViaSessionService()
    {
        using var engine = new FocusEngineService();
        var sessions = new FakeSessionService();
        var vm = CreateVm(engine, sessions);

        var session = new FocusSession
        {
            Id = Guid.NewGuid(),
            Mode = FocusMode.Pomodoro,
            ElapsedSeconds = 1500,
            IsCompleted = true
        };
        await sessions.SaveSessionAsync(session);

        vm.GetType().GetProperty(nameof(FocusViewModel.PendingJournalSession))!
            .SetValue(vm, session);
        vm.JournalNoteDraft = "Deep work done";
        vm.JournalEnergyRating = 4;
        vm.ShowJournalPanel = true;

        await vm.SaveJournalCommand.ExecuteAsync(null);

        Assert.Single(sessions.JournalUpdates);
        Assert.Equal(session.Id, sessions.JournalUpdates[0].Id);
        Assert.Equal("Deep work done", sessions.JournalUpdates[0].Note);
        Assert.Equal(4, sessions.JournalUpdates[0].Rating);
        Assert.False(vm.ShowJournalPanel);
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
        public List<(Guid Id, string? Note, int? Rating)> JournalUpdates { get; } = new();

        public Task SaveSessionAsync(FocusSession session)
        {
            Saved.Add(session);
            return Task.CompletedTask;
        }

        public Task UpdateJournalAsync(Guid sessionId, string? journalNote, int? energyRating)
        {
            JournalUpdates.Add((sessionId, journalNote, energyRating));
            return Task.CompletedTask;
        }

        public Task<List<FocusSession>> GetRecentSessionsAsync(int count = 20) =>
            Task.FromResult(new List<FocusSession>());

        public Task<List<FocusSession>> GetSessionsInRangeAsync(DateTime utcStartInclusive, DateTime utcEndExclusive) =>
            Task.FromResult(new List<FocusSession>());

        public Task<int> GetTodayFocusMinutesAsync(DateTime? utcNow = null) => Task.FromResult(0);

        public Task<int> GetTotalFocusSecondsAsync(DateTime utcStartInclusive, DateTime utcEndExclusive) =>
            Task.FromResult(0);

        public Task<(int CurrentStreak, int BestStreak)> GetStreaksAsync(DateTime? utcToday = null) =>
            Task.FromResult((0, 0));

        public Task<List<ModeBreakdownItem>> GetModeBreakdownAsync(DateTime utcStartInclusive, DateTime utcEndExclusive) =>
            Task.FromResult(new List<ModeBreakdownItem>());

        public Task<List<FocusSession>> GetUnsyncedCompletedSessionsAsync() =>
            Task.FromResult(new List<FocusSession>());

        public Task MarkSessionsSyncedAsync(IEnumerable<Guid> sessionIds) => Task.CompletedTask;
    }

    private sealed class FakeTaskService : ITaskService
    {
        public Task<List<TaskItem>> GetAllTasksAsync() => Task.FromResult(new List<TaskItem>());
        public Task<List<TaskItem>> GetTodayTasksAsync() => Task.FromResult(new List<TaskItem>());
        public Task<List<TaskItem>> GetUpcomingTasksAsync() => Task.FromResult(new List<TaskItem>());
        public Task<List<TaskItem>> GetInboxTasksAsync() => Task.FromResult(new List<TaskItem>());
        public Task<TaskItem> CreateTaskAsync(string title, string? description = null, int estimatedMinutes = 25, DateTime? dueDate = null, Guid? parentTaskId = null, int priority = 0, string energyLevel = "", string? recurrenceRule = null, int estimatedPomodoros = 0) =>
            Task.FromResult(new TaskItem { Title = title });
        public Task<TaskItem?> UpdateTaskAsync(TaskItem task) => Task.FromResult<TaskItem?>(task);
        public Task ToggleTaskCompletionAsync(Guid taskId) => Task.CompletedTask;
        public Task DeleteTaskAsync(Guid taskId) => Task.CompletedTask;
    }

    private sealed class FakeNotificationService : INotificationService
    {
        public void ShowSessionCompletedToast(string sessionName, int durationMinutes) { }
        public void ShowBreakStartedToast(bool isLongBreak) { }
        public void ShowBreakCompletedToast() { }
        public void ShowStreakMilestoneToast(int streakDays) { }
    }

    private sealed class FakeFocusAssistService : IFocusAssistService
    {
        public void BeginFocusSession() { }
        public void EndFocusSession() { }
    }
}
