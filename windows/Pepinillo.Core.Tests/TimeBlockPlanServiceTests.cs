using System;
using System.Linq;
using System.Threading.Tasks;
using Microsoft.EntityFrameworkCore;
using Pepinillo.Core.Data;
using Pepinillo.Core.Models;
using Pepinillo.Core.Services;
using Xunit;

namespace Pepinillo.Core.Tests;

public class TimeBlockPlanServiceTests
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

    [Fact]
    public async Task Premium_CanCreateListAndDelete()
    {
        using var db = CreateDb();
        var service = new TimeBlockPlanService(db, PlusEntitlements());
        var day = new DateTime(2026, 8, 4, 0, 0, 0, DateTimeKind.Utc);
        var start = day.AddHours(9);

        var created = await service.CreateAsync(start, 60, "Deep work", null);
        Assert.Equal("Deep work", created.Title);
        Assert.Equal(60, created.DurationMinutes);
        Assert.Equal(start, created.StartAtUtc);

        var list = await service.GetForDayAsync(day);
        Assert.Single(list);
        Assert.Equal(created.Id, list[0].Id);

        await service.DeleteAsync(created.Id);
        list = await service.GetForDayAsync(day);
        Assert.Empty(list);
    }

    [Fact]
    public async Task Free_CannotCreate()
    {
        using var db = CreateDb();
        var service = new TimeBlockPlanService(db, FreeEntitlements());
        var start = new DateTime(2026, 8, 4, 10, 0, 0, DateTimeKind.Utc);

        var ex = await Assert.ThrowsAsync<InvalidOperationException>(() =>
            service.CreateAsync(start, 45));

        Assert.Contains("Time Blocking", ex.Message, StringComparison.OrdinalIgnoreCase);
        Assert.Equal(0, await db.PlannedTimeBlocks.CountAsync());
    }

    [Fact]
    public async Task GetForDay_FiltersUtcCalendarDay()
    {
        using var db = CreateDb();
        var service = new TimeBlockPlanService(db, PlusEntitlements());
        var day = new DateTime(2026, 8, 4, 0, 0, 0, DateTimeKind.Utc);

        await service.CreateAsync(day.AddHours(8), 30, "Morning");
        await service.CreateAsync(day.AddHours(14), 45, "Afternoon");
        await service.CreateAsync(day.AddDays(1).AddHours(9), 60, "Next day");
        await service.CreateAsync(day.AddDays(-1).AddHours(20), 30, "Previous day");

        var list = await service.GetForDayAsync(day);
        Assert.Equal(2, list.Count);
        Assert.Equal(new[] { "Morning", "Afternoon" }, list.Select(b => b.Title).ToArray());
    }

    [Fact]
    public async Task GetBetween_RespectsHalfOpenRange()
    {
        using var db = CreateDb();
        var service = new TimeBlockPlanService(db, PlusEntitlements());
        var start = new DateTime(2026, 8, 4, 3, 0, 0, DateTimeKind.Utc);
        var end = start.AddDays(1);

        await service.CreateAsync(start, 30, "Boundary start");
        await service.CreateAsync(end.AddMinutes(-1), 30, "Near end");
        await service.CreateAsync(end, 30, "At exclusive end");

        var list = await service.GetBetweenAsync(start, end);
        Assert.Equal(2, list.Count);
        Assert.DoesNotContain(list, b => b.Title == "At exclusive end");
    }

    [Fact]
    public async Task Create_ClampsDurationAndDefaultTitle()
    {
        using var db = CreateDb();
        var service = new TimeBlockPlanService(db, PlusEntitlements());
        var start = new DateTime(2026, 8, 4, 11, 0, 0, DateTimeKind.Utc);

        var shortBlock = await service.CreateAsync(start, 1, "  ");
        Assert.Equal(5, shortBlock.DurationMinutes);
        Assert.Equal("Time Block", shortBlock.Title);

        var longBlock = await service.CreateAsync(start.AddHours(2), 999, "Long");
        Assert.Equal(12 * 60, longBlock.DurationMinutes);
    }

    [Fact]
    public async Task Create_LinksOptionalTaskId()
    {
        using var db = CreateDb();
        var service = new TimeBlockPlanService(db, PlusEntitlements());
        var taskId = Guid.NewGuid();
        var start = new DateTime(2026, 8, 4, 12, 0, 0, DateTimeKind.Utc);

        var block = await service.CreateAsync(start, 50, "With task", taskId);
        Assert.Equal(taskId, block.TaskItemId);

        var loaded = await db.PlannedTimeBlocks.FindAsync(block.Id);
        Assert.NotNull(loaded);
        Assert.Equal(taskId, loaded!.TaskItemId);
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
            DateTime? lastSyncAt = null) =>
            Task.FromResult(new Pepinillo.Core.Models.Sync.SessionSyncClientResult { Success = false });
        public Task<Pepinillo.Core.Models.Sync.FullSyncClientResult> PullSessionsAsync(
            int limit = 100, string? sessionCursor = null) =>
            Task.FromResult(new Pepinillo.Core.Models.Sync.FullSyncClientResult { Success = false });
        public Task<SubscriptionStatus> GetSubscriptionStatusAsync() =>
            Task.FromResult(new SubscriptionStatus { Tier = EntitlementTier.Free });
    }
}
