using System;
using System.Threading.Tasks;
using Microsoft.EntityFrameworkCore;
using Pepinillo.Core.Data;
using Pepinillo.Core.Models;
using Pepinillo.Core.Services;
using Xunit;

namespace Pepinillo.Core.Tests;

public class TaskServiceTests
{
    private static PepinilloDbContext CreateInMemoryDbContext()
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

    [Fact]
    public async Task CreateTask_ShouldAddTaskToDatabase()
    {
        using var dbContext = CreateInMemoryDbContext();
        var service = new TaskService(dbContext, FreeEntitlements());

        var task = await service.CreateTaskAsync("Escribir documentación", estimatedMinutes: 45);

        Assert.NotNull(task);
        Assert.Equal("Escribir documentación", task.Title);
        Assert.Equal(45, task.EstimatedMinutes);
        Assert.False(task.IsCompleted);
        Assert.True(task.EstimatedPomodoros >= 1);
    }

    [Fact]
    public async Task CreateTask_WithPriorityEnergyRecurrence_OnPlus_ShouldPersist()
    {
        using var dbContext = CreateInMemoryDbContext();
        var service = new TaskService(dbContext, PlusEntitlements());

        var task = await service.CreateTaskAsync(
            "Deep refactor",
            estimatedMinutes: 50,
            priority: 3,
            energyLevel: "deep",
            recurrenceRule: "DAILY");

        Assert.Equal(3, task.Priority);
        Assert.Equal("deep", task.EnergyLevel);
        Assert.Equal("FREQ=DAILY", task.RecurrenceRule);
        Assert.Equal(2, task.EstimatedPomodoros); // ceil(50/25)

        var loaded = await dbContext.TaskItems.FindAsync(task.Id);
        Assert.NotNull(loaded);
        Assert.Equal("FREQ=DAILY", loaded!.RecurrenceRule);
        Assert.Equal("deep", loaded.EnergyLevel);
    }

    [Fact]
    public async Task Free_BlocksFourthIncompleteRootTask()
    {
        using var dbContext = CreateInMemoryDbContext();
        var service = new TaskService(dbContext, FreeEntitlements());

        await service.CreateTaskAsync("t1");
        await service.CreateTaskAsync("t2");
        await service.CreateTaskAsync("t3");

        var ex = await Assert.ThrowsAsync<InvalidOperationException>(() =>
            service.CreateTaskAsync("t4"));

        Assert.Contains("3", ex.Message);
    }

    [Fact]
    public async Task Free_BlocksSubtaskAndRecurrence()
    {
        using var dbContext = CreateInMemoryDbContext();
        var service = new TaskService(dbContext, FreeEntitlements());
        var parent = await service.CreateTaskAsync("parent");

        await Assert.ThrowsAsync<InvalidOperationException>(() =>
            service.CreateTaskAsync("child", parentTaskId: parent.Id));

        await Assert.ThrowsAsync<InvalidOperationException>(() =>
            service.CreateTaskAsync("recur", recurrenceRule: "DAILY"));
    }

    [Fact]
    public async Task Plus_AllowsUnlimitedRootsAndSubtasks()
    {
        using var dbContext = CreateInMemoryDbContext();
        var service = new TaskService(dbContext, PlusEntitlements());

        for (var i = 0; i < 5; i++)
            await service.CreateTaskAsync($"t{i}");

        var parent = await service.CreateTaskAsync("parent");
        var child = await service.CreateTaskAsync("child", parentTaskId: parent.Id);
        Assert.Equal(parent.Id, child.ParentTaskId);
    }

    [Fact]
    public async Task ToggleTaskCompletion_ShouldSwitchState()
    {
        using var dbContext = CreateInMemoryDbContext();
        var service = new TaskService(dbContext, FreeEntitlements());

        var task = await service.CreateTaskAsync("Refactorizar motor de tiempos");
        Assert.False(task.IsCompleted);

        await service.ToggleTaskCompletionAsync(task.Id);
        var updated = await dbContext.TaskItems.FindAsync(task.Id);

        Assert.NotNull(updated);
        Assert.True(updated.IsCompleted);
    }

    [Fact]
    public async Task GetTodayTasks_ShouldReturnOnlyTodayTasks()
    {
        using var dbContext = CreateInMemoryDbContext();
        var service = new TaskService(dbContext, FreeEntitlements());

        await service.CreateTaskAsync("Tarea de Hoy", dueDate: DateTime.UtcNow.Date);
        await service.CreateTaskAsync("Tarea de Mañana", dueDate: DateTime.UtcNow.Date.AddDays(1));

        var todayTasks = await service.GetTodayTasksAsync();

        Assert.Single(todayTasks);
        Assert.Equal("Tarea de Hoy", todayTasks[0].Title);
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
            System.Collections.Generic.IEnumerable<FocusSession> sessions,
            System.DateTime? lastSyncAt = null) =>
            Task.FromResult(new Pepinillo.Core.Models.Sync.SessionSyncClientResult { Success = false });
        public Task<Pepinillo.Core.Models.Sync.FullSyncClientResult> PullSessionsAsync(
            int limit = 100, string? sessionCursor = null) =>
            Task.FromResult(new Pepinillo.Core.Models.Sync.FullSyncClientResult { Success = false });
        public Task<SubscriptionStatus> GetSubscriptionStatusAsync() =>
            Task.FromResult(new SubscriptionStatus { Tier = EntitlementTier.Free });

    }
}
