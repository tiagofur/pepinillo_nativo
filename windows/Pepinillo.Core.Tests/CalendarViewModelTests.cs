using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Microsoft.EntityFrameworkCore;
using Pepinillo.Core.Data;
using Pepinillo.Core.Models;
using Pepinillo.Core.Services;
using Pepinillo.Core.ViewModels;
using Xunit;

namespace Pepinillo.Core.Tests;

public class CalendarViewModelTests
{
    private static PepinilloDbContext CreateDb()
    {
        var options = new DbContextOptionsBuilder<PepinilloDbContext>()
            .UseInMemoryDatabase(databaseName: Guid.NewGuid().ToString())
            .Options;
        return new PepinilloDbContext(options);
    }

    private static IEntitlementService FreeEntitlements()
    {
        var e = new EntitlementService(new StoreCommerceService(new NoAuthBackend()));
        e.ApplyStatus(new SubscriptionStatus { Tier = EntitlementTier.Free });
        return e;
    }

    private static IEntitlementService PlusEntitlements()
    {
        var e = new EntitlementService(new StoreCommerceService(new NoAuthBackend()));
        e.ApplyStatus(new SubscriptionStatus { Tier = EntitlementTier.PepinilloPlus });
        return e;
    }

    private static FocusViewModel CreateFocus(IEntitlementService entitlements, IFocusEngineService? engine = null)
    {
        engine ??= new FocusEngineService();
        return new FocusViewModel(
            engine,
            new FixedSettingsService(),
            new NoopSessionService(),
            new EmptyTaskService(),
            new NoopNotificationService(),
            new NoopFocusAssistService(),
            entitlements: entitlements);
    }

    private static CalendarViewModel CreateVm(
        PepinilloDbContext db,
        IEntitlementService entitlements,
        FocusViewModel? focus = null)
    {
        focus ??= CreateFocus(entitlements);
        return new CalendarViewModel(
            new TimeBlockPlanService(db, entitlements),
            new FixedSettingsService(),
            new EmptyTaskService(),
            entitlements,
            focus,
            new LocalizationService());
    }

    [Fact]
    public async Task Premium_CreateAtHour_AddsBlockForSelectedDay()
    {
        using var db = CreateDb();
        var entitlements = PlusEntitlements();
        var vm = CreateVm(db, entitlements);
        vm.SelectedDay = new DateTime(2026, 8, 4);

        await vm.CreateAtHourCommand.ExecuteAsync(9);
        await vm.LoadDayCommand.ExecuteAsync(null);

        Assert.False(vm.IsEmpty);
        Assert.Single(vm.PlannedBlocks);
        Assert.Equal(60, vm.PlannedBlocks[0].DurationMinutes);
        Assert.Equal(string.Empty, vm.StatusMessage);
    }

    [Fact]
    public async Task Free_CreateAtHour_RaisesPaywall_DoesNotPersist()
    {
        using var db = CreateDb();
        var entitlements = FreeEntitlements();
        var vm = CreateVm(db, entitlements);
        string? feature = null;
        vm.PremiumFeatureRequested += (_, f) => feature = f;

        await vm.CreateAtHourCommand.ExecuteAsync(10);

        Assert.Equal("time_blocking", feature);
        Assert.False(string.IsNullOrWhiteSpace(vm.StatusMessage));
        Assert.Equal(0, await db.PlannedTimeBlocks.CountAsync());
    }

    [Fact]
    public async Task Premium_StartBlock_ConfiguresFocusAndNavigates()
    {
        using var db = CreateDb();
        using var engine = new FocusEngineService();
        var entitlements = PlusEntitlements();
        var focus = CreateFocus(entitlements, engine);
        var vm = CreateVm(db, entitlements, focus);
        vm.SelectedDay = DateTime.Today;

        await vm.CreateAtHourCommand.ExecuteAsync(11);
        await vm.LoadDayCommand.ExecuteAsync(null);
        var row = vm.PlannedBlocks.Single();

        var navigated = 0;
        vm.NavigateToFocusRequested += (_, _) => navigated++;

        vm.StartBlockCommand.Execute(row);

        Assert.Equal(1, navigated);
        Assert.Equal(FocusMode.TimeBlocking, focus.SelectedMode);
        Assert.Equal(FocusMode.TimeBlocking, engine.CurrentMode);
        Assert.Equal(row.DurationMinutes * 60, engine.TargetDurationSeconds);
        Assert.Equal(SessionState.Idle, engine.CurrentState);

        // InitializeAsync must not wipe calendar configuration.
        await focus.InitializeAsync();
        Assert.Equal(FocusMode.TimeBlocking, focus.SelectedMode);
        Assert.Equal(row.DurationMinutes * 60, engine.TargetDurationSeconds);
    }

    [Fact]
    public async Task Free_StartBlock_RaisesPaywall()
    {
        using var db = CreateDb();
        // Seed as premium then switch... service gates create; for start we only need a row.
        var plus = PlusEntitlements();
        var plan = new TimeBlockPlanService(db, plus);
        var block = await plan.CreateAsync(
            DateTime.UtcNow.Date.AddHours(12),
            40,
            "Seed");

        var free = FreeEntitlements();
        var focus = CreateFocus(free);
        var vm = new CalendarViewModel(
            plan,
            new FixedSettingsService(),
            new EmptyTaskService(),
            free,
            focus);

        await vm.LoadDayCommand.ExecuteAsync(null);
        // May be empty depending on local day vs UTC seed — inject row directly via start with synthetic row.
        var row = new CalendarBlockRow
        {
            Id = block.Id,
            StartAtUtc = block.StartAtUtc,
            DurationMinutes = block.DurationMinutes,
            Title = block.Title
        };

        string? feature = null;
        vm.PremiumFeatureRequested += (_, f) => feature = f;
        var navigated = 0;
        vm.NavigateToFocusRequested += (_, _) => navigated++;

        vm.StartBlockCommand.Execute(row);

        Assert.Equal("time_blocking", feature);
        Assert.Equal(0, navigated);
        Assert.NotEqual(FocusMode.TimeBlocking, focus.SelectedMode);
    }

    [Fact]
    public async Task DeleteBlock_RemovesFromList()
    {
        using var db = CreateDb();
        var entitlements = PlusEntitlements();
        var vm = CreateVm(db, entitlements);
        vm.SelectedDay = DateTime.Today;

        await vm.CreateAtHourCommand.ExecuteAsync(8);
        await vm.LoadDayCommand.ExecuteAsync(null);
        Assert.Single(vm.PlannedBlocks);

        await vm.DeleteBlockCommand.ExecuteAsync(vm.PlannedBlocks[0]);
        Assert.True(vm.IsEmpty);
        Assert.Empty(vm.PlannedBlocks);
    }

    [Fact]
    public async Task DayNavigation_ChangesSelectedDay()
    {
        using var db = CreateDb();
        var vm = CreateVm(db, PlusEntitlements());
        var start = new DateTime(2026, 8, 4);
        vm.SelectedDay = start;

        await vm.NextDayCommand.ExecuteAsync(null);
        Assert.Equal(start.AddDays(1), vm.SelectedDay.Date);

        await vm.PrevDayCommand.ExecuteAsync(null);
        Assert.Equal(start, vm.SelectedDay.Date);

        await vm.GoTodayCommand.ExecuteAsync(null);
        Assert.Equal(DateTime.Today, vm.SelectedDay.Date);
    }

    [Fact]
    public void HourSlots_CoverDefaultGrid()
    {
        using var db = CreateDb();
        var vm = CreateVm(db, PlusEntitlements());
        Assert.Equal(17, vm.HourSlots.Count); // 6..22 inclusive
        Assert.Equal(6, vm.HourSlots.First().HourLocal);
        Assert.Equal(22, vm.HourSlots.Last().HourLocal);
    }

    private sealed class FixedSettingsService : ISettingsService
    {
        public Task<UserSettings> GetSettingsAsync() =>
            Task.FromResult(new UserSettings { TimeBlockingMinutes = 60, PreferredLanguage = "en" });

        public Task SaveSettingsAsync(UserSettings settings) => Task.CompletedTask;
    }

    private sealed class EmptyTaskService : ITaskService
    {
        public Task<List<TaskItem>> GetAllTasksAsync() => Task.FromResult(new List<TaskItem>());
        public Task<List<TaskItem>> GetTodayTasksAsync() => Task.FromResult(new List<TaskItem>());
        public Task<List<TaskItem>> GetUpcomingTasksAsync() => Task.FromResult(new List<TaskItem>());
        public Task<List<TaskItem>> GetInboxTasksAsync() => Task.FromResult(new List<TaskItem>());
        public Task<TaskItem> CreateTaskAsync(
            string title, string? description = null, int estimatedMinutes = 25,
            DateTime? dueDate = null, Guid? parentTaskId = null, int priority = 0,
            string energyLevel = "", string? recurrenceRule = null, int estimatedPomodoros = 0) =>
            Task.FromResult(new TaskItem { Title = title });
        public Task<TaskItem?> UpdateTaskAsync(TaskItem task) => Task.FromResult<TaskItem?>(task);
        public Task ToggleTaskCompletionAsync(Guid taskId) => Task.CompletedTask;
        public Task DeleteTaskAsync(Guid taskId) => Task.CompletedTask;
    }

    private sealed class NoopSessionService : IFocusSessionService
    {
        public Task SaveSessionAsync(FocusSession session) => Task.CompletedTask;
        public Task UpdateJournalAsync(Guid sessionId, string? journalNote, int? energyRating) => Task.CompletedTask;
        public Task<List<FocusSession>> GetRecentSessionsAsync(int count = 20) =>
            Task.FromResult(new List<FocusSession>());
        public Task<List<FocusSession>> GetSessionsInRangeAsync(DateTime utcStartInclusive, DateTime utcEndExclusive) =>
            Task.FromResult(new List<FocusSession>());
        public Task<int> GetTodayFocusMinutesAsync(DateTime? utcNow = null) => Task.FromResult(0);
        public Task<int> GetTotalFocusSecondsAsync(DateTime utcStartInclusive, DateTime utcEndExclusive) =>
            Task.FromResult(0);
        public Task<(int CurrentStreak, int BestStreak, bool ProtectionApplied)> GetStreaksAsync(DateTime? utcToday = null) =>
            Task.FromResult((0, 0, false));
        public Task<List<ModeBreakdownItem>> GetModeBreakdownAsync(DateTime utcStartInclusive, DateTime utcEndExclusive) =>
            Task.FromResult(new List<ModeBreakdownItem>());
        public Task<List<FocusSession>> GetUnsyncedCompletedSessionsAsync() =>
            Task.FromResult(new List<FocusSession>());
        public Task MarkSessionsSyncedAsync(IEnumerable<Guid> sessionIds) => Task.CompletedTask;
        public Task<bool> UpsertFromRemoteAsync(FocusSession remote) => Task.FromResult(false);
    }

    private sealed class NoopNotificationService : INotificationService
    {
        public void ShowSessionCompletedToast(string sessionName, int durationMinutes) { }
        public void ShowBreakStartedToast(bool isLongBreak) { }
        public void ShowBreakCompletedToast() { }
        public void ShowStreakMilestoneToast(int streakDays) { }
    }

    private sealed class NoopFocusAssistService : IFocusAssistService
    {
        public string FocusAssistStatus => "Focus Assist: test host";
        public void BeginFocusSession() { }
        public void EndFocusSession() { }
    }

    private sealed class NoAuthBackend : IBackendApiClient
    {
        public bool IsAuthenticated => false;
        public string? AuthToken => null;
        public int? LastStatusCode => null;
        public string? LastError => null;
        public Task InitializeAsync() => Task.CompletedTask;
        public Task<bool> LoginAsync(string email, string password) => Task.FromResult(false);
        public Task<bool> RegisterAsync(string email, string password, string name) => Task.FromResult(false);
        public Task<bool> RefreshAsync() => Task.FromResult(false);
        public Task LogoutAsync() => Task.CompletedTask;
        public Task<Pepinillo.Core.Models.Sync.SessionSyncClientResult> SyncSessionsAsync(
            IEnumerable<FocusSession> sessions, DateTime? lastSyncAt = null) =>
            Task.FromResult(new Pepinillo.Core.Models.Sync.SessionSyncClientResult { Success = false });
        public Task<Pepinillo.Core.Models.Sync.FullSyncClientResult> PullSessionsAsync(
            int limit = 100, string? sessionCursor = null) =>
            Task.FromResult(new Pepinillo.Core.Models.Sync.FullSyncClientResult { Success = false });
        public Task<SubscriptionStatus> GetSubscriptionStatusAsync() =>
            Task.FromResult(new SubscriptionStatus { Tier = EntitlementTier.Free });
    }
}
