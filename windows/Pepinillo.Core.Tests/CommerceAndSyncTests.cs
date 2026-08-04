using System;
using System.Collections.Generic;
using System.Linq;
using System.Net.Http;
using System.Threading.Tasks;
using Microsoft.EntityFrameworkCore;
using Pepinillo.Core.Data;
using Pepinillo.Core.Models;
using Pepinillo.Core.Services;
using Xunit;

namespace Pepinillo.Core.Tests;

public class CommerceAndSyncTests
{
    [Fact]
    public async Task CheckStoreEntitlements_ShouldDefaultToFree_WhenNotAuthenticated()
    {
        var httpClient = new HttpClient();
        var tokenStore = new MemoryAuthTokenStore();
        var backendClient = new BackendApiClient(httpClient, tokenStore);
        var commerceService = new StoreCommerceService(backendClient);

        var status = await commerceService.CheckStoreEntitlementsAsync();

        Assert.NotNull(status);
        Assert.Equal(EntitlementTier.Free, status.Tier);
        Assert.False(status.IsActive);
        Assert.False(commerceService.HasPremiumEntitlement());
    }

    [Fact]
    public async Task BackendApiClient_PersistsToken_OnLogin_WhenServerReturnsToken()
    {
        // Without a real server, login fails — token store stays empty.
        var store = new MemoryAuthTokenStore();
        var client = new BackendApiClient(new HttpClient(), store);
        var ok = await client.LoginAsync("a@b.com", "secret");
        Assert.False(ok);
        Assert.Null(await store.GetTokenAsync());
        Assert.False(client.IsAuthenticated);
    }

    [Fact]
    public async Task MemoryAuthTokenStore_RoundTrip()
    {
        var store = new MemoryAuthTokenStore();
        await store.SetTokenAsync("abc123");
        Assert.Equal("abc123", await store.GetTokenAsync());
        await store.ClearAsync();
        Assert.Null(await store.GetTokenAsync());
    }

    [Fact]
    public async Task SyncService_MarksSessionsSynced_WhenBackendSucceeds()
    {
        await using var db = CreateDb();
        var sessions = new FocusSessionService(db);
        var session = new FocusSession
        {
            Mode = FocusMode.Pomodoro,
            ElapsedSeconds = 1500,
            IsCompleted = true,
            IsSynced = false,
            StartedAt = DateTime.UtcNow.Date.AddHours(9)
        };
        await sessions.SaveSessionAsync(session);

        var backend = new FakeBackend { IsAuthenticated = true, SyncSessionsResult = true };
        var commerce = new StoreCommerceService(backend);
        var sync = new SyncService(backend, sessions, commerce);

        var result = await sync.SyncNowAsync();

        Assert.True(result.Success);
        Assert.Equal(1, result.SessionsPushed);

        var reloaded = await db.FocusSessions.FindAsync(session.Id);
        Assert.NotNull(reloaded);
        Assert.True(reloaded!.IsSynced);
    }

    [Fact]
    public async Task SyncService_WhenNotAuthenticated_DoesNotMarkSynced()
    {
        await using var db = CreateDb();
        var sessions = new FocusSessionService(db);
        await sessions.SaveSessionAsync(new FocusSession
        {
            Mode = FocusMode.Stopwatch,
            ElapsedSeconds = 120,
            IsCompleted = true,
            IsSynced = false,
            StartedAt = DateTime.UtcNow
        });

        var backend = new FakeBackend { IsAuthenticated = false };
        var commerce = new StoreCommerceService(backend);
        var sync = new SyncService(backend, sessions, commerce);

        var result = await sync.SyncNowAsync();
        Assert.False(result.Success);
        Assert.False(result.WasAuthenticated);

        var unsynced = await sessions.GetUnsyncedCompletedSessionsAsync();
        Assert.Single(unsynced);
    }

    private static PepinilloDbContext CreateDb()
    {
        var options = new DbContextOptionsBuilder<PepinilloDbContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString())
            .Options;
        return new PepinilloDbContext(options);
    }

    private sealed class FakeBackend : IBackendApiClient
    {
        public bool IsAuthenticated { get; set; }
        public string? AuthToken { get; private set; }
        public bool SyncSessionsResult { get; set; }

        public Task InitializeAsync() => Task.CompletedTask;
        public Task<bool> LoginAsync(string email, string password) => Task.FromResult(false);
        public Task<bool> RegisterAsync(string email, string password, string name) => Task.FromResult(false);
        public Task LogoutAsync()
        {
            IsAuthenticated = false;
            AuthToken = null;
            return Task.CompletedTask;
        }

        public Task<bool> SyncSessionsAsync(IEnumerable<FocusSession> sessions) =>
            Task.FromResult(SyncSessionsResult && sessions.Any());

        public Task<SubscriptionStatus> GetSubscriptionStatusAsync() =>
            Task.FromResult(new SubscriptionStatus { Tier = EntitlementTier.Free });
    }
}
