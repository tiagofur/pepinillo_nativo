using System;
using System.Collections.Generic;
using System.Linq;
using System.Net;
using System.Net.Http;
using System.Text;
using System.Threading;
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
    public async Task BackendApiClient_Login_ParsesNestedTokens()
    {
        var handler = new StubHttpHandler((request, _) =>
        {
            Assert.Equal(HttpMethod.Post, request.Method);
            Assert.Contains("/auth/login", request.RequestUri!.ToString());
            var json = """
                {
                  "user": { "id": "u1", "email": "a@b.com" },
                  "tokens": {
                    "accessToken": "access-xyz",
                    "refreshToken": "refresh-xyz",
                    "expiresIn": 3600
                  }
                }
                """;
            return new HttpResponseMessage(HttpStatusCode.OK)
            {
                Content = new StringContent(json, Encoding.UTF8, "application/json")
            };
        });

        var store = new MemoryAuthTokenStore();
        var client = new BackendApiClient(new HttpClient(handler), store);

        var ok = await client.LoginAsync("a@b.com", "secret");

        Assert.True(ok);
        Assert.True(client.IsAuthenticated);
        Assert.Equal("access-xyz", client.AuthToken);
        Assert.Equal("access-xyz", await store.GetAccessTokenAsync());
        Assert.Equal("refresh-xyz", await store.GetRefreshTokenAsync());
    }

    [Fact]
    public async Task BackendApiClient_Login_AcceptsLegacyRootToken()
    {
        var handler = new StubHttpHandler((_, _) =>
            new HttpResponseMessage(HttpStatusCode.OK)
            {
                Content = new StringContent(
                    """{"token":"legacy-access"}""",
                    Encoding.UTF8,
                    "application/json")
            });

        var store = new MemoryAuthTokenStore();
        var client = new BackendApiClient(new HttpClient(handler), store);

        Assert.True(await client.LoginAsync("a@b.com", "secret"));
        Assert.Equal("legacy-access", client.AuthToken);
        Assert.Equal("legacy-access", await store.GetAccessTokenAsync());
    }

    [Fact]
    public async Task BackendApiClient_Refresh_UsesRefreshTokenBody()
    {
        var calls = 0;
        var handler = new StubHttpHandler((request, _) =>
        {
            calls++;
            Assert.Contains("/auth/refresh", request.RequestUri!.ToString());
            var body = request.Content!.ReadAsStringAsync().GetAwaiter().GetResult();
            Assert.Contains("refresh-old", body);

            return new HttpResponseMessage(HttpStatusCode.OK)
            {
                Content = new StringContent(
                    """{"tokens":{"accessToken":"access-new","refreshToken":"refresh-new","expiresIn":3600}}""",
                    Encoding.UTF8,
                    "application/json")
            };
        });

        var store = new MemoryAuthTokenStore();
        await store.SetTokensAsync("access-old", "refresh-old");
        var client = new BackendApiClient(new HttpClient(handler), store);
        await client.InitializeAsync();

        var ok = await client.RefreshAsync();

        Assert.True(ok);
        Assert.Equal(1, calls);
        Assert.Equal("access-new", client.AuthToken);
        Assert.Equal("access-new", await store.GetAccessTokenAsync());
        Assert.Equal("refresh-new", await store.GetRefreshTokenAsync());
    }

    [Fact]
    public async Task BackendApiClient_SyncSessions_RetriesOnceAfter401Refresh()
    {
        var syncCalls = 0;
        var handler = new StubHttpHandler((request, _) =>
        {
            var path = request.RequestUri!.AbsolutePath;
            if (path.EndsWith("/auth/refresh", StringComparison.Ordinal))
            {
                return new HttpResponseMessage(HttpStatusCode.OK)
                {
                    Content = new StringContent(
                        """{"tokens":{"accessToken":"access-2","refreshToken":"refresh-2","expiresIn":3600}}""",
                        Encoding.UTF8,
                        "application/json")
                };
            }

            if (path.Contains("/sync/sessions", StringComparison.Ordinal))
            {
                syncCalls++;
                if (syncCalls == 1)
                    return new HttpResponseMessage(HttpStatusCode.Unauthorized);
                return new HttpResponseMessage(HttpStatusCode.OK)
                {
                    Content = new StringContent("{}", Encoding.UTF8, "application/json")
                };
            }

            return new HttpResponseMessage(HttpStatusCode.NotFound);
        });

        var store = new MemoryAuthTokenStore();
        await store.SetTokensAsync("access-1", "refresh-1");
        var client = new BackendApiClient(new HttpClient(handler), store);
        await client.InitializeAsync();

        var ok = await client.SyncSessionsAsync(new[]
        {
            new FocusSession { Mode = FocusMode.Pomodoro, ElapsedSeconds = 60, IsCompleted = true }
        });

        Assert.True(ok);
        Assert.Equal(2, syncCalls);
        Assert.Equal("access-2", client.AuthToken);
    }

    [Fact]
    public async Task BackendApiClient_Logout_ClearsBothTokens()
    {
        var store = new MemoryAuthTokenStore();
        await store.SetTokensAsync("a", "r");
        var client = new BackendApiClient(new HttpClient(new StubHttpHandler((_, _) =>
            new HttpResponseMessage(HttpStatusCode.OK))), store);
        await client.InitializeAsync();
        Assert.True(client.IsAuthenticated);

        await client.LogoutAsync();

        Assert.False(client.IsAuthenticated);
        Assert.Null(await store.GetAccessTokenAsync());
        Assert.Null(await store.GetRefreshTokenAsync());
    }

    [Fact]
    public async Task MemoryAuthTokenStore_RoundTripBothTokens()
    {
        var store = new MemoryAuthTokenStore();
        await store.SetTokensAsync("abc123", "ref456");
        Assert.Equal("abc123", await store.GetAccessTokenAsync());
        Assert.Equal("ref456", await store.GetRefreshTokenAsync());
        await store.ClearAsync();
        Assert.Null(await store.GetAccessTokenAsync());
        Assert.Null(await store.GetRefreshTokenAsync());
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

    [Fact]
    public void EntitlementService_Free_BlocksPremiumModesAndLimitsTasks()
    {
        var entitlements = new EntitlementService(new StoreCommerceService(new FakeBackend()));
        Assert.False(entitlements.IsPremium);
        Assert.True(entitlements.CanUseFocusMode(FocusMode.Pomodoro));
        Assert.True(entitlements.CanUseFocusMode(FocusMode.Stopwatch));
        Assert.False(entitlements.CanUseFocusMode(FocusMode.Flowtime));
        Assert.False(entitlements.CanUseFocusMode(FocusMode.TimeBlocking));
        Assert.True(entitlements.CanCreateIncompleteRootTask(2));
        Assert.False(entitlements.CanCreateIncompleteRootTask(3));
        Assert.False(entitlements.CanCreateSubtask);
        Assert.False(entitlements.CanUseRecurrence);
        Assert.Equal(7, entitlements.MaxAnalyticsHistoryDays);
    }

    [Fact]
    public void EntitlementService_Plus_UnlocksPremiumFeatures()
    {
        var entitlements = new EntitlementService(new StoreCommerceService(new FakeBackend()));
        entitlements.ApplyStatus(new SubscriptionStatus { Tier = EntitlementTier.PepinilloPlus });

        Assert.True(entitlements.IsPremium);
        Assert.True(entitlements.CanUseFocusMode(FocusMode.Flowtime));
        Assert.True(entitlements.CanUseFocusMode(FocusMode.TimeBlocking));
        Assert.True(entitlements.CanCreateIncompleteRootTask(100));
        Assert.True(entitlements.CanCreateSubtask);
        Assert.True(entitlements.CanUseRecurrence);
        Assert.Equal(int.MaxValue, entitlements.MaxAnalyticsHistoryDays);
        Assert.True(entitlements.CanUseTheme("Forest"));
        Assert.True(entitlements.CanUseTheme("Sunset"));
    }

    [Fact]
    public void EntitlementService_Free_BlocksPremiumThemes()
    {
        var entitlements = new EntitlementService(new StoreCommerceService(new FakeBackend()));
        Assert.True(entitlements.CanUseTheme("System"));
        Assert.True(entitlements.CanUseTheme("Light"));
        Assert.True(entitlements.CanUseTheme("Dark"));
        Assert.True(entitlements.CanUseTheme("OLEDBlack"));
        Assert.False(entitlements.CanUseTheme("Forest"));
        Assert.False(entitlements.CanUseTheme("Ocean"));
        Assert.False(entitlements.CanUseTheme("Sunset"));
    }

    private static PepinilloDbContext CreateDb()
    {
        var options = new DbContextOptionsBuilder<PepinilloDbContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString())
            .Options;
        return new PepinilloDbContext(options);
    }

    private sealed class StubHttpHandler : HttpMessageHandler
    {
        private readonly Func<HttpRequestMessage, CancellationToken, HttpResponseMessage> _handler;

        public StubHttpHandler(Func<HttpRequestMessage, CancellationToken, HttpResponseMessage> handler)
        {
            _handler = handler;
        }

        protected override Task<HttpResponseMessage> SendAsync(
            HttpRequestMessage request,
            CancellationToken cancellationToken) =>
            Task.FromResult(_handler(request, cancellationToken));
    }

    private sealed class FakeBackend : IBackendApiClient
    {
        public bool IsAuthenticated { get; set; }
        public string? AuthToken { get; private set; }
        public bool SyncSessionsResult { get; set; }

        public Task InitializeAsync() => Task.CompletedTask;
        public Task<bool> LoginAsync(string email, string password) => Task.FromResult(false);
        public Task<bool> RegisterAsync(string email, string password, string name) => Task.FromResult(false);
        public Task<bool> RefreshAsync() => Task.FromResult(false);

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
