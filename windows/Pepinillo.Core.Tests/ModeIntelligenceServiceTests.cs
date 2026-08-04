using System;
using System.Collections.Generic;
using System.Linq;
using Pepinillo.Core.Models;
using Pepinillo.Core.Services;
using Pepinillo.Core.ViewModels;
using Xunit;

namespace Pepinillo.Core.Tests;

public class ModeIntelligenceServiceTests
{
    private readonly ModeIntelligenceService _service = new();

    private static FocusSession MakeSession(
        FocusMode mode,
        int elapsedSeconds,
        bool completed,
        Guid? taskId,
        DateTime? startedAt = null) =>
        new()
        {
            Id = Guid.NewGuid(),
            Mode = mode,
            ElapsedSeconds = elapsedSeconds,
            IsCompleted = completed,
            TaskItemId = taskId,
            StartedAt = startedAt ?? DateTime.UtcNow,
            CompletedAt = completed ? (startedAt ?? DateTime.UtcNow).AddSeconds(elapsedSeconds) : null
        };

    // --- Task-linked: minimum sessions ---

    [Fact]
    public void Task_ReturnsNull_WhenBelowMinimumSessions()
    {
        var taskId = Guid.NewGuid();
        var sessions = new[]
        {
            MakeSession(FocusMode.Pomodoro, 1500, true, taskId),
            MakeSession(FocusMode.Pomodoro, 1500, true, taskId),
        };

        var suggestion = _service.Suggest(sessions, taskId, null, DateTime.UtcNow, isPremium: true);
        Assert.Null(suggestion);
    }

    [Fact]
    public void Task_ReturnsNull_WhenWrongTaskId()
    {
        var task1 = Guid.NewGuid();
        var task2 = Guid.NewGuid();
        var sessions = Enumerable.Range(0, 5)
            .Select(_ => MakeSession(FocusMode.Pomodoro, 1500, true, task2))
            .ToList();

        // Task-only API ignores other tasks entirely.
        Assert.Null(_service.SuggestForTask(sessions, task1));
        // Full Suggest may still fall back to Global when enough recent history exists.
        var full = _service.Suggest(sessions, task1, null, DateTime.UtcNow, isPremium: true);
        Assert.NotNull(full);
        Assert.Equal(ModeSuggestionSource.Global, full!.Source);
    }

    [Fact]
    public void Task_ReturnsNull_WhenNoCompletedSessions()
    {
        var taskId = Guid.NewGuid();
        var sessions = Enumerable.Range(0, 5)
            .Select(_ => MakeSession(FocusMode.Pomodoro, 300, false, taskId))
            .ToList();

        Assert.Null(_service.Suggest(sessions, taskId, null, DateTime.UtcNow, isPremium: true));
    }

    [Fact]
    public void Task_SuggestsDominantMode()
    {
        var taskId = Guid.NewGuid();
        var sessions = Enumerable.Range(0, 5)
            .Select(_ => MakeSession(FocusMode.Pomodoro, 1500, true, taskId))
            .ToList();

        var suggestion = _service.Suggest(sessions, taskId, null, DateTime.UtcNow, isPremium: true);
        Assert.NotNull(suggestion);
        Assert.Equal(FocusMode.Pomodoro, suggestion!.SuggestedMode);
        Assert.Equal(ModeSuggestionSource.Task, suggestion.Source);
        Assert.False(suggestion.IsLocked);
        Assert.InRange(suggestion.Confidence, 0.0, 1.0);
        Assert.False(string.IsNullOrWhiteSpace(suggestion.Reason));
        Assert.Contains("Pomodoro", suggestion.Reason);
    }

    [Fact]
    public void Task_FiltersByTaskId()
    {
        var task1 = Guid.NewGuid();
        var task2 = Guid.NewGuid();
        var sessions = Enumerable.Range(0, 3)
            .Select(_ => MakeSession(FocusMode.Pomodoro, 1500, true, task1))
            .Concat(Enumerable.Range(0, 3)
                .Select(_ => MakeSession(FocusMode.Flowtime, 1800, true, task2)))
            .ToList();

        var suggestion = _service.Suggest(sessions, task1, null, DateTime.UtcNow, isPremium: true);
        Assert.Equal(FocusMode.Pomodoro, suggestion!.SuggestedMode);
    }

    [Fact]
    public void Task_ReturnsNull_WhenCompletionRateBelowThreshold()
    {
        // Only completed sessions enter the pool (iOS). With 2 completed of 4 total
        // for the task, completed-only count is 2 < min 3 → null.
        var taskId = Guid.NewGuid();
        var sessions = new[]
        {
            MakeSession(FocusMode.Pomodoro, 1500, true, taskId),
            MakeSession(FocusMode.Pomodoro, 1500, true, taskId),
            MakeSession(FocusMode.Pomodoro, 1500, false, taskId),
            MakeSession(FocusMode.Pomodoro, 1500, false, taskId),
        };

        Assert.Null(_service.Suggest(sessions, taskId, null, DateTime.UtcNow, isPremium: true));
    }

    [Fact]
    public void Task_ReturnsNull_WhenMarginTooClose()
    {
        var taskId = Guid.NewGuid();
        var sessions = Enumerable.Range(0, 3)
            .Select(_ => MakeSession(FocusMode.Pomodoro, 1500, true, taskId))
            .Concat(Enumerable.Range(0, 3)
                .Select(_ => MakeSession(FocusMode.Flowtime, 1500, true, taskId)))
            .ToList();

        Assert.Null(_service.Suggest(sessions, taskId, null, DateTime.UtcNow, isPremium: true));
    }

    [Fact]
    public void Free_ReturnsLockedSuggestion_WhenDataQualifies()
    {
        var taskId = Guid.NewGuid();
        var sessions = Enumerable.Range(0, 5)
            .Select(_ => MakeSession(FocusMode.Pomodoro, 1500, true, taskId))
            .ToList();

        var suggestion = _service.Suggest(sessions, taskId, null, DateTime.UtcNow, isPremium: false);
        Assert.NotNull(suggestion);
        Assert.True(suggestion!.IsLocked);
        Assert.Equal(FocusMode.Pomodoro, suggestion.SuggestedMode);
    }

    // --- Energy ---

    [Fact]
    public void Energy_ReturnsNull_WhenBelowMinimum()
    {
        var taskId = Guid.NewGuid();
        var sessions = Enumerable.Range(0, 3)
            .Select(_ => MakeSession(FocusMode.Pomodoro, 1500, true, taskId))
            .ToList();
        var map = new Dictionary<Guid, string> { [taskId] = "deep" };

        Assert.Null(_service.SuggestForEnergy(sessions, "deep", map, minimumSessions: 5));
    }

    [Fact]
    public void Energy_ReturnsSuggestion_WhenSufficient()
    {
        var taskId = Guid.NewGuid();
        var sessions = Enumerable.Range(0, 5)
            .Select(_ => MakeSession(FocusMode.Pomodoro, 1500, true, taskId))
            .ToList();
        var map = new Dictionary<Guid, string> { [taskId] = "deep" };

        var suggestion = _service.Suggest(sessions, taskId: null, taskEnergy: "deep",
            DateTime.UtcNow, isPremium: true, taskEnergyById: map);
        Assert.NotNull(suggestion);
        Assert.Equal(ModeSuggestionSource.Energy, suggestion!.Source);
        Assert.Contains("Deep", suggestion.Reason);
    }

    // --- Global fallback ---

    [Fact]
    public void Global_ReturnsNull_WhenFewerThanFiveRecent()
    {
        var utcNow = new DateTime(2026, 8, 4, 14, 0, 0, DateTimeKind.Utc);
        var sessions = Enumerable.Range(0, 4)
            .Select(i => MakeSession(FocusMode.Stopwatch, 600, true, null, utcNow.AddDays(-i)))
            .ToList();

        Assert.Null(_service.Suggest(sessions, null, null, utcNow, isPremium: true));
    }

    [Fact]
    public void Global_SuggestsMode_FromRecentHistory()
    {
        var utcNow = new DateTime(2026, 8, 4, 14, 0, 0, DateTimeKind.Utc);
        var sessions = Enumerable.Range(0, 5)
            .Select(i => MakeSession(FocusMode.Flowtime, 1800, true, null, utcNow.AddDays(-i).AddHours(0)))
            .ToList();

        var suggestion = _service.Suggest(sessions, null, null, utcNow, isPremium: true);
        Assert.NotNull(suggestion);
        Assert.Equal(FocusMode.Flowtime, suggestion!.SuggestedMode);
        Assert.Equal(ModeSuggestionSource.Global, suggestion.Source);
        Assert.Contains("Flowtime", suggestion.Reason);
    }

    [Fact]
    public void Global_PrefersHourBucket_WhenEnoughSessions()
    {
        var utcNow = new DateTime(2026, 8, 4, 14, 0, 0, DateTimeKind.Utc);
        // 5 Pomodoro around hour 14; 5 Stopwatch around hour 3 — bucket should pick Pomodoro.
        var sessions = new List<FocusSession>();
        for (var i = 0; i < 5; i++)
        {
            sessions.Add(MakeSession(FocusMode.Pomodoro, 1500, true, null,
                utcNow.AddDays(-i))); // same hour 14
            sessions.Add(MakeSession(FocusMode.Stopwatch, 900, true, null,
                utcNow.AddDays(-i).Date.AddHours(3)));
        }

        var suggestion = _service.Suggest(sessions, null, null, utcNow, isPremium: true);
        Assert.NotNull(suggestion);
        Assert.Equal(FocusMode.Pomodoro, suggestion!.SuggestedMode);
        Assert.Contains("Around this time", suggestion.Reason);
    }

    [Fact]
    public void Task_TakesPriority_OverGlobal()
    {
        var utcNow = new DateTime(2026, 8, 4, 14, 0, 0, DateTimeKind.Utc);
        var taskId = Guid.NewGuid();
        var sessions = Enumerable.Range(0, 5)
            .Select(i => MakeSession(FocusMode.Stopwatch, 600, true, taskId, utcNow.AddDays(-i)))
            .Concat(Enumerable.Range(0, 5)
                .Select(i => MakeSession(FocusMode.Pomodoro, 1500, true, null, utcNow.AddDays(-i))))
            .ToList();

        var suggestion = _service.Suggest(sessions, taskId, null, utcNow, isPremium: true);
        Assert.Equal(FocusMode.Stopwatch, suggestion!.SuggestedMode);
        Assert.Equal(ModeSuggestionSource.Task, suggestion.Source);
    }

    // --- ViewModel integration ---

    [Fact]
    public async Task FocusViewModel_Premium_ShowsSuggestionBanner()
    {
        using var engine = new FocusEngineService();
        var taskId = Guid.NewGuid();
        var sessions = new FakeSessionsForIntel();
        var utcNow = DateTime.UtcNow;
        for (var i = 0; i < 5; i++)
        {
            sessions.Stored.Add(MakeSession(FocusMode.Pomodoro, 1500, true, taskId, utcNow.AddDays(-i)));
        }

        var tasks = new FakeTasksForIntel(new TaskItem { Id = taskId, Title = "Write" });
        var entitlements = PlusEntitlements();
        var vm = new FocusViewModel(
            engine,
            new FakeSettingsForIntel(),
            sessions,
            tasks,
            new FakeNotify(),
            new FakeAssist(),
            entitlements: entitlements,
            modeIntelligence: new ModeIntelligenceService());

        await vm.InitializeAsync();
        await vm.LinkTaskCommand.ExecuteAsync(new TaskItem { Id = taskId, Title = "Write" });

        Assert.True(vm.ShowModeSuggestion);
        Assert.False(vm.ShowModeSuggestionLocked);
        Assert.Equal("Pomodoro", vm.SuggestedModeLabel);
        Assert.Contains("Pomodoro", vm.SuggestionReason);
    }

    [Fact]
    public async Task FocusViewModel_Free_ShowsLockedTeaser()
    {
        using var engine = new FocusEngineService();
        var taskId = Guid.NewGuid();
        var sessions = new FakeSessionsForIntel();
        var utcNow = DateTime.UtcNow;
        for (var i = 0; i < 5; i++)
            sessions.Stored.Add(MakeSession(FocusMode.Pomodoro, 1500, true, taskId, utcNow.AddDays(-i)));

        var vm = new FocusViewModel(
            engine,
            new FakeSettingsForIntel(),
            sessions,
            new FakeTasksForIntel(new TaskItem { Id = taskId, Title = "Write" }),
            new FakeNotify(),
            new FakeAssist(),
            entitlements: FreeEntitlements(),
            modeIntelligence: new ModeIntelligenceService());

        await vm.InitializeAsync();
        await vm.LinkTaskCommand.ExecuteAsync(new TaskItem { Id = taskId, Title = "Write" });

        Assert.False(vm.ShowModeSuggestion);
        Assert.True(vm.ShowModeSuggestionLocked);
        Assert.Equal("Upgrade for Mode Intelligence", vm.SuggestionReason);

        string? requested = null;
        vm.PremiumFeatureRequested += (_, f) => requested = f;
        vm.UpgradeModeIntelligenceCommand.Execute(null);
        Assert.Equal("Mode Intelligence", requested);
    }

    [Fact]
    public async Task FocusViewModel_ApplySuggestion_ConfiguresMode()
    {
        using var engine = new FocusEngineService();
        var taskId = Guid.NewGuid();
        var sessions = new FakeSessionsForIntel();
        var utcNow = DateTime.UtcNow;
        for (var i = 0; i < 5; i++)
            sessions.Stored.Add(MakeSession(FocusMode.Flowtime, 1800, true, taskId, utcNow.AddDays(-i)));

        var vm = new FocusViewModel(
            engine,
            new FakeSettingsForIntel(),
            sessions,
            new FakeTasksForIntel(new TaskItem { Id = taskId, Title = "Deep" }),
            new FakeNotify(),
            new FakeAssist(),
            entitlements: PlusEntitlements(),
            modeIntelligence: new ModeIntelligenceService());

        await vm.InitializeAsync();
        await vm.LinkTaskCommand.ExecuteAsync(new TaskItem { Id = taskId, Title = "Deep" });
        Assert.True(vm.ShowModeSuggestion);

        vm.ApplySuggestionCommand.Execute(null);

        Assert.Equal(FocusMode.Flowtime, vm.SelectedMode);
        Assert.False(vm.ShowModeSuggestion);
        Assert.Equal(1800, engine.TargetDurationSeconds);
    }

    private static IEntitlementService FreeEntitlements()
    {
        var e = new EntitlementService(new StoreCommerceService(new NoAuthBackendIntel()));
        e.ApplyStatus(new SubscriptionStatus { Tier = EntitlementTier.Free });
        return e;
    }

    private static IEntitlementService PlusEntitlements()
    {
        var e = new EntitlementService(new StoreCommerceService(new NoAuthBackendIntel()));
        e.ApplyStatus(new SubscriptionStatus { Tier = EntitlementTier.PepinilloPlus });
        return e;
    }

    private sealed class FakeSessionsForIntel : IFocusSessionService
    {
        public List<FocusSession> Stored { get; } = new();

        public Task SaveSessionAsync(FocusSession session)
        {
            Stored.Add(session);
            return Task.CompletedTask;
        }

        public Task UpdateJournalAsync(Guid sessionId, string? journalNote, int? energyRating) =>
            Task.CompletedTask;

        public Task<List<FocusSession>> GetRecentSessionsAsync(int count = 20) =>
            Task.FromResult(Stored.OrderByDescending(s => s.StartedAt).Take(count).ToList());

        public Task<List<FocusSession>> GetSessionsInRangeAsync(DateTime utcStartInclusive, DateTime utcEndExclusive) =>
            Task.FromResult(Stored
                .Where(s => s.StartedAt >= utcStartInclusive && s.StartedAt < utcEndExclusive)
                .ToList());

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

    private sealed class FakeTasksForIntel : ITaskService
    {
        private readonly List<TaskItem> _tasks;
        public FakeTasksForIntel(params TaskItem[] tasks) => _tasks = tasks.ToList();

        public Task<List<TaskItem>> GetAllTasksAsync() => Task.FromResult(_tasks.ToList());
        public Task<List<TaskItem>> GetTodayTasksAsync() => Task.FromResult(_tasks.ToList());
        public Task<List<TaskItem>> GetUpcomingTasksAsync() => Task.FromResult(new List<TaskItem>());
        public Task<List<TaskItem>> GetInboxTasksAsync() => Task.FromResult(new List<TaskItem>());
        public Task<TaskItem> CreateTaskAsync(string title, string? description = null, int estimatedMinutes = 25, DateTime? dueDate = null, Guid? parentTaskId = null, int priority = 0, string energyLevel = "", string? recurrenceRule = null, int estimatedPomodoros = 0) =>
            Task.FromResult(new TaskItem { Title = title });
        public Task<TaskItem?> UpdateTaskAsync(TaskItem task) => Task.FromResult<TaskItem?>(task);
        public Task ToggleTaskCompletionAsync(Guid taskId) => Task.CompletedTask;
        public Task DeleteTaskAsync(Guid taskId) => Task.CompletedTask;
    }

    private sealed class FakeSettingsForIntel : ISettingsService
    {
        private UserSettings _settings = new();
        public Task<UserSettings> GetSettingsAsync() => Task.FromResult(_settings);
        public Task SaveSettingsAsync(UserSettings settings)
        {
            _settings = settings;
            return Task.CompletedTask;
        }
    }

    private sealed class FakeNotify : INotificationService
    {
        public void ShowSessionCompletedToast(string sessionName, int durationMinutes) { }
        public void ShowBreakStartedToast(bool isLongBreak) { }
        public void ShowBreakCompletedToast() { }
        public void ShowStreakMilestoneToast(int streakDays) { }
    }

    private sealed class FakeAssist : IFocusAssistService
    {
        public string FocusAssistStatus => "test";
        public void BeginFocusSession() { }
        public void EndFocusSession() { }
    }

    private sealed class NoAuthBackendIntel : IBackendApiClient
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
