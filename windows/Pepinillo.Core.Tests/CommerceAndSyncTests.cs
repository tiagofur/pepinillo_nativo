using System;
using System.Collections.Generic;
using System.Linq;
using System.Net;
using System.Net.Http;
using System.Text;
using System.Text.Json;
using System.Threading;
using System.Threading.Tasks;
using Microsoft.EntityFrameworkCore;
using Pepinillo.Core.Data;
using Pepinillo.Core.Models;
using Pepinillo.Core.Models.Sync;
using Pepinillo.Core.Services;
using Pepinillo.Core.ViewModels;
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
    public async Task RestorePurchases_ReRunsEntitlementCheck_DefaultsFree()
    {
        var commerce = new StoreCommerceService(new FakeBackend());

        var status = await commerce.RestorePurchasesAsync();

        Assert.Equal(EntitlementTier.Free, status.Tier);
        Assert.False(status.IsActive);
        Assert.Same(status, commerce.CachedStatus);
        Assert.Null(commerce.LastError);
    }

    [Fact]
    public async Task RestorePurchases_UsesBackendActiveTier_WhenAuthenticated()
    {
        var backend = new FakeBackend
        {
            IsAuthenticated = true,
            Subscription = new SubscriptionStatus
            {
                Tier = EntitlementTier.EverywherePlus,
                SourceStore = "Backend"
            }
        };
        var commerce = new StoreCommerceService(backend);

        var status = await commerce.RestorePurchasesAsync();

        Assert.Equal(EntitlementTier.EverywherePlus, status.Tier);
        Assert.True(commerce.HasPremiumEntitlement());
        Assert.Equal("Backend", status.SourceStore);
    }

    [Fact]
    public void MergeStatuses_PrefersEverywhereOverPlusOverFree()
    {
        var free = new SubscriptionStatus { Tier = EntitlementTier.Free, SourceStore = "A" };
        var plus = new SubscriptionStatus { Tier = EntitlementTier.PepinilloPlus, SourceStore = "Store" };
        var everywhere = new SubscriptionStatus { Tier = EntitlementTier.EverywherePlus, SourceStore = "Backend" };

        Assert.Equal(EntitlementTier.EverywherePlus, StoreCommerceService.MergeStatuses(plus, everywhere).Tier);
        Assert.Equal(EntitlementTier.EverywherePlus, StoreCommerceService.MergeStatuses(everywhere, plus).Tier);
        Assert.Equal(EntitlementTier.PepinilloPlus, StoreCommerceService.MergeStatuses(free, plus).Tier);
        Assert.Equal(EntitlementTier.EverywherePlus, StoreCommerceService.MergeStatuses(free, everywhere).Tier);
        Assert.Equal(EntitlementTier.Free, StoreCommerceService.MergeStatuses(null, null).Tier);
    }

    [Fact]
    public async Task CorePurchase_ReturnsHonestFailure_WithoutSimulatedCopy()
    {
        var commerce = new StoreCommerceService(new FakeBackend());

        var result = await commerce.PurchasePepinilloPlusAsync();

        Assert.False(result.Success);
        Assert.NotNull(commerce.LastError);
        Assert.Contains("Microsoft Store", result.Message, StringComparison.OrdinalIgnoreCase);
        Assert.DoesNotContain("simulated", result.Message, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public async Task PaywallViewModel_Restore_UpdatesTierAndEntitlements()
    {
        var commerce = new FakeCommerce
        {
            RestoreStatus = new SubscriptionStatus
            {
                Tier = EntitlementTier.PepinilloPlus,
                SourceStore = "MicrosoftStore"
            }
        };
        var entitlements = new EntitlementService(commerce);
        var vm = new PaywallViewModel(commerce, entitlements);

        await vm.RestorePurchasesCommand.ExecuteAsync(null);

        Assert.Contains("Pepinillo+", vm.CurrentTierLabel, StringComparison.OrdinalIgnoreCase);
        Assert.Contains("MicrosoftStore", vm.CurrentTierLabel, StringComparison.OrdinalIgnoreCase);
        Assert.True(entitlements.IsPremium);
        Assert.Contains("restored", vm.StatusMessage, StringComparison.OrdinalIgnoreCase);
        Assert.DoesNotContain("simulated", vm.StatusMessage, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public async Task PaywallViewModel_Purchase_SurfacesCommerceResult_AndAppliesEntitlements()
    {
        var plus = new SubscriptionStatus
        {
            Tier = EntitlementTier.PepinilloPlus,
            SourceStore = "MicrosoftStore"
        };
        var commerce = new FakeCommerce
        {
            PurchaseResult = CommerceResult.Ok("Purchase successful.", plus)
        };
        var entitlements = new EntitlementService(commerce);
        var vm = new PaywallViewModel(commerce, entitlements);

        await vm.PurchasePepinilloPlusCommand.ExecuteAsync(null);

        Assert.Equal("Purchase successful.", vm.StatusMessage);
        Assert.DoesNotContain("simulated", vm.StatusMessage, StringComparison.OrdinalIgnoreCase);
        Assert.True(entitlements.IsPremium);
        Assert.Contains("Pepinillo+", vm.CurrentTierLabel, StringComparison.OrdinalIgnoreCase);
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

        var result = await client.SyncSessionsAsync(new[]
        {
            new FocusSession { Mode = FocusMode.Pomodoro, ElapsedSeconds = 60, IsCompleted = true }
        });

        Assert.True(result.Success);
        Assert.Equal(2, syncCalls);
        Assert.Equal("access-2", client.AuthToken);
    }

    [Fact]
    public async Task BackendApiClient_SyncSessions_PostsWrappedBodyWithMappedMode()
    {
        string? body = null;
        string? deviceHeader = null;
        var handler = new StubHttpHandler((request, _) =>
        {
            if (request.RequestUri!.AbsolutePath.Contains("/sync/sessions", StringComparison.Ordinal))
            {
                body = request.Content!.ReadAsStringAsync().GetAwaiter().GetResult();
                if (request.Headers.TryGetValues("X-Device-ID", out var values))
                    deviceHeader = values.FirstOrDefault();
                return new HttpResponseMessage(HttpStatusCode.OK)
                {
                    Content = new StringContent(
                        """{"sessions":[],"serverTimestamp":"2026-08-04T00:00:00Z"}""",
                        Encoding.UTF8,
                        "application/json")
                };
            }

            return new HttpResponseMessage(HttpStatusCode.NotFound);
        });

        var store = new MemoryAuthTokenStore();
        await store.SetTokensAsync("access-1", "refresh-1");
        var client = new BackendApiClient(new HttpClient(handler), store);
        await client.InitializeAsync();

        var sessionId = Guid.Parse("11111111-1111-1111-1111-111111111111");
        var result = await client.SyncSessionsAsync(new[]
        {
            new FocusSession
            {
                Id = sessionId,
                Mode = FocusMode.TimeBlocking,
                TargetDurationSeconds = 3600,
                ElapsedSeconds = 1200,
                IsCompleted = true,
                StartedAt = new DateTime(2026, 1, 1, 12, 0, 0, DateTimeKind.Utc),
                CompletedAt = new DateTime(2026, 1, 1, 12, 20, 0, DateTimeKind.Utc),
                JournalNote = "note",
                EnergyRating = 4
            }
        }, lastSyncAt: new DateTime(2026, 1, 1, 0, 0, 0, DateTimeKind.Utc));

        Assert.True(result.Success);
        Assert.False(string.IsNullOrWhiteSpace(deviceHeader));
        Assert.NotNull(body);
        using var doc = JsonDocument.Parse(body!);
        var root = doc.RootElement;
        Assert.True(root.TryGetProperty("sessions", out var sessions));
        Assert.Equal(JsonValueKind.Array, sessions.ValueKind);
        Assert.Equal(1, sessions.GetArrayLength());
        var s0 = sessions[0];
        Assert.Equal(sessionId.ToString(), s0.GetProperty("id").GetString());
        Assert.Equal("timeblock", s0.GetProperty("mode").GetString());
        Assert.Equal("focus", s0.GetProperty("phase").GetString());
        Assert.Equal(3600, s0.GetProperty("durationSeconds").GetInt32());
        Assert.Equal(1200, s0.GetProperty("elapsedSeconds").GetInt32());
        Assert.True(s0.GetProperty("wasCompleted").GetBoolean());
        Assert.Equal(4, s0.GetProperty("satisfactionRating").GetInt32());
        Assert.True(root.TryGetProperty("lastSyncAt", out _));
        // Must not be a raw top-level array
        Assert.NotEqual(JsonValueKind.Array, root.ValueKind);
    }

    [Fact]
    public async Task BackendApiClient_SyncSessions_403_RequiresEverywhere()
    {
        var handler = new StubHttpHandler((_, _) =>
            new HttpResponseMessage(HttpStatusCode.Forbidden)
            {
                Content = new StringContent("""{"error":"subscription_required"}""", Encoding.UTF8, "application/json")
            });

        var store = new MemoryAuthTokenStore();
        await store.SetTokensAsync("a", "r");
        var client = new BackendApiClient(new HttpClient(handler), store);
        await client.InitializeAsync();

        var result = await client.SyncSessionsAsync(new[]
        {
            new FocusSession { Mode = FocusMode.Pomodoro, ElapsedSeconds = 10, IsCompleted = true }
        });

        Assert.False(result.Success);
        Assert.True(result.RequiresEverywhere);
        Assert.Contains("Everywhere", result.ErrorMessage, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public async Task BackendApiClient_PullSessions_ParsesFullSyncPage()
    {
        var handler = new StubHttpHandler((request, _) =>
        {
            Assert.Contains("/sync/full", request.RequestUri!.ToString(), StringComparison.Ordinal);
            var json = """
                {
                  "sessions": {
                    "items": [
                      {
                        "id": "22222222-2222-2222-2222-222222222222",
                        "startedAt": "2026-02-01T10:00:00Z",
                        "endedAt": "2026-02-01T10:25:00Z",
                        "mode": "flowtime",
                        "phase": "focus",
                        "durationSeconds": 1500,
                        "elapsedSeconds": 1500,
                        "wasCompleted": true,
                        "journalNote": "remote",
                        "satisfactionRating": 5
                      }
                    ],
                    "nextCursor": "",
                    "hasMore": false
                  },
                  "serverTimestamp": "2026-02-01T12:00:00Z"
                }
                """;
            return new HttpResponseMessage(HttpStatusCode.OK)
            {
                Content = new StringContent(json, Encoding.UTF8, "application/json")
            };
        });

        var store = new MemoryAuthTokenStore();
        await store.SetTokensAsync("a", "r");
        var client = new BackendApiClient(new HttpClient(handler), store);
        await client.InitializeAsync();

        var pull = await client.PullSessionsAsync(100);
        Assert.True(pull.Success);
        Assert.Single(pull.Sessions);
        Assert.Equal("flowtime", pull.Sessions[0].Mode);
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
        var settings = new SettingsService(db);
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
        var sync = new SyncService(backend, sessions, commerce, settings);

        var result = await sync.SyncNowAsync();

        Assert.True(result.Success);
        Assert.Equal(1, result.SessionsPushed);

        var reloaded = await db.FocusSessions.FindAsync(session.Id);
        Assert.NotNull(reloaded);
        Assert.True(reloaded!.IsSynced);

        var savedSettings = await settings.GetSettingsAsync();
        Assert.NotNull(savedSettings.LastSyncAtUtc);
    }

    [Fact]
    public async Task SyncService_WhenNotAuthenticated_DoesNotMarkSynced()
    {
        await using var db = CreateDb();
        var sessions = new FocusSessionService(db);
        var settings = new SettingsService(db);
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
        var sync = new SyncService(backend, sessions, commerce, settings);

        var result = await sync.SyncNowAsync();
        Assert.False(result.Success);
        Assert.False(result.WasAuthenticated);
        Assert.Contains("Everywhere", result.Message, StringComparison.OrdinalIgnoreCase);

        var unsynced = await sessions.GetUnsyncedCompletedSessionsAsync();
        Assert.Single(unsynced);
    }

    [Fact]
    public async Task SyncService_PullsAndUpsertsRemoteSessions()
    {
        await using var db = CreateDb();
        var sessions = new FocusSessionService(db);
        var settings = new SettingsService(db);
        var remoteId = Guid.Parse("33333333-3333-3333-3333-333333333333");

        var backend = new FakeBackend
        {
            IsAuthenticated = true,
            SyncSessionsResult = true,
            PullSessions =
            {
                new ServerFocusSessionDto
                {
                    Id = remoteId.ToString(),
                    Mode = "stopwatch",
                    Phase = "focus",
                    StartedAt = new DateTime(2026, 3, 1, 8, 0, 0, DateTimeKind.Utc),
                    EndedAt = new DateTime(2026, 3, 1, 8, 10, 0, DateTimeKind.Utc),
                    DurationSeconds = 0,
                    ElapsedSeconds = 600,
                    WasCompleted = true,
                    JournalNote = "from cloud"
                }
            }
        };
        var commerce = new StoreCommerceService(backend);
        var sync = new SyncService(backend, sessions, commerce, settings);

        var result = await sync.SyncNowAsync();

        Assert.True(result.Success);
        Assert.True(result.SessionsPulled >= 1);
        var local = await db.FocusSessions.FindAsync(remoteId);
        Assert.NotNull(local);
        Assert.Equal(FocusMode.Stopwatch, local!.Mode);
        Assert.Equal(600, local.ElapsedSeconds);
        Assert.True(local.IsSynced);
        Assert.Equal("from cloud", local.JournalNote);
    }

    [Fact]
    public async Task FocusSessionService_UpsertFromRemote_KeepsLocalWhenElapsedGreater()
    {
        await using var db = CreateDb();
        var sessions = new FocusSessionService(db);
        var id = Guid.NewGuid();
        await sessions.SaveSessionAsync(new FocusSession
        {
            Id = id,
            Mode = FocusMode.Pomodoro,
            ElapsedSeconds = 2000,
            IsCompleted = true,
            IsSynced = true,
            JournalNote = "local journal",
            StartedAt = DateTime.UtcNow.AddHours(-1)
        });

        var updated = await sessions.UpsertFromRemoteAsync(new FocusSession
        {
            Id = id,
            Mode = FocusMode.Flowtime,
            ElapsedSeconds = 500,
            IsCompleted = true,
            JournalNote = "remote journal",
            StartedAt = DateTime.UtcNow.AddHours(-1)
        });

        Assert.False(updated);
        var local = await db.FocusSessions.FindAsync(id);
        Assert.Equal(2000, local!.ElapsedSeconds);
        Assert.Equal(FocusMode.Pomodoro, local.Mode);
        Assert.Equal("local journal", local.JournalNote);
    }

    [Fact]
    public async Task AuthViewModel_Register_AutoSignsIn_WhenTokensPresent()
    {
        await using var db = CreateDb();
        var settings = new SettingsService(db);
        var backend = new FakeBackend
        {
            RegisterSetsAuthenticated = true,
            SyncSessionsResult = true
        };
        var commerce = new StoreCommerceService(backend);
        var sessions = new FocusSessionService(db);
        var sync = new SyncService(backend, sessions, commerce, settings);
        var vm = new AuthViewModel(backend, sync, settings)
        {
            Email = "user@example.com",
            Password = "secret",
            DisplayName = "User"
        };

        await vm.RegisterCommand.ExecuteAsync(null);

        Assert.True(vm.IsAuthenticated);
        Assert.Contains("Signed in", vm.AccountModeLabel, StringComparison.OrdinalIgnoreCase);
        // Auto-sync after register may replace the "signed in" toast with sync result.
        Assert.False(string.IsNullOrWhiteSpace(vm.StatusMessage));
    }

    [Fact]
    public async Task AuthViewModel_Login_RejectsInvalidEmail()
    {
        await using var db = CreateDb();
        var settings = new SettingsService(db);
        var backend = new FakeBackend();
        var sync = new SyncService(backend, new FocusSessionService(db), new StoreCommerceService(backend), settings);
        var vm = new AuthViewModel(backend, sync, settings)
        {
            Email = "not-an-email",
            Password = "secret"
        };

        await vm.LoginCommand.ExecuteAsync(null);

        Assert.False(vm.IsAuthenticated);
        Assert.Contains("valid email", vm.StatusMessage, StringComparison.OrdinalIgnoreCase);
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
        public bool RegisterSetsAuthenticated { get; set; }
        public int? LastStatusCode { get; private set; }
        public string? LastError { get; private set; }
        public List<ServerFocusSessionDto> PullSessions { get; } = new();
        public SubscriptionStatus Subscription { get; set; } = new() { Tier = EntitlementTier.Free };

        public Task InitializeAsync() => Task.CompletedTask;

        public Task<bool> LoginAsync(string email, string password)
        {
            IsAuthenticated = true;
            AuthToken = "token";
            return Task.FromResult(true);
        }

        public Task<bool> RegisterAsync(string email, string password, string name)
        {
            if (RegisterSetsAuthenticated)
            {
                IsAuthenticated = true;
                AuthToken = "token";
            }

            return Task.FromResult(true);
        }

        public Task<bool> RefreshAsync() => Task.FromResult(false);

        public Task LogoutAsync()
        {
            IsAuthenticated = false;
            AuthToken = null;
            return Task.CompletedTask;
        }

        public Task<SessionSyncClientResult> SyncSessionsAsync(
            IEnumerable<FocusSession> sessions,
            DateTime? lastSyncAt = null)
        {
            var list = sessions.ToList();
            // Empty push is fine; non-empty requires SyncSessionsResult.
            var ok = list.Count == 0 || SyncSessionsResult;
            return Task.FromResult(new SessionSyncClientResult
            {
                Success = ok,
                Sessions = Array.Empty<ServerFocusSessionDto>()
            });
        }

        public Task<FullSyncClientResult> PullSessionsAsync(int limit = 100, string? sessionCursor = null) =>
            Task.FromResult(new FullSyncClientResult
            {
                Success = true,
                Sessions = PullSessions
            });

        public Task<SubscriptionStatus> GetSubscriptionStatusAsync() =>
            Task.FromResult(Subscription);
    }

    private sealed class FakeCommerce : IStoreCommerceService
    {
        public SubscriptionStatus? CachedStatus { get; private set; }
        public string? LastError { get; set; }
        public SubscriptionStatus RestoreStatus { get; set; } = new() { Tier = EntitlementTier.Free };
        public CommerceResult PurchaseResult { get; set; } =
            CommerceResult.Fail("Store purchases require the Microsoft Store install.");
        public CommerceResult SubscribeResult { get; set; } =
            CommerceResult.Fail("Store subscriptions require the Microsoft Store install.");

        public Task<SubscriptionStatus> CheckStoreEntitlementsAsync()
        {
            CachedStatus ??= new SubscriptionStatus { Tier = EntitlementTier.Free, SourceStore = "MicrosoftStore" };
            return Task.FromResult(CachedStatus);
        }

        public Task<SubscriptionStatus> RestorePurchasesAsync()
        {
            CachedStatus = RestoreStatus;
            return Task.FromResult(RestoreStatus);
        }

        public Task<CommerceResult> PurchasePepinilloPlusAsync()
        {
            if (PurchaseResult.Status != null)
                CachedStatus = PurchaseResult.Status;
            LastError = PurchaseResult.Success ? null : PurchaseResult.Message;
            return Task.FromResult(PurchaseResult);
        }

        public Task<CommerceResult> SubscribeEverywherePlusAsync(bool annual = false)
        {
            if (SubscribeResult.Status != null)
                CachedStatus = SubscribeResult.Status;
            LastError = SubscribeResult.Success ? null : SubscribeResult.Message;
            return Task.FromResult(SubscribeResult);
        }

        public bool HasPremiumEntitlement()
        {
            var tier = CachedStatus?.Tier ?? EntitlementTier.Free;
            return tier is EntitlementTier.PepinilloPlus or EntitlementTier.EverywherePlus;
        }
    }
}
