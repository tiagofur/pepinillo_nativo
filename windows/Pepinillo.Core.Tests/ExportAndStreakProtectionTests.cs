using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using Microsoft.EntityFrameworkCore;
using Pepinillo.Core.Data;
using Pepinillo.Core.Models;
using Pepinillo.Core.Services;
using Pepinillo.Core.ViewModels;
using Xunit;

namespace Pepinillo.Core.Tests;

public class ExportAndStreakProtectionTests
{
    private static PepinilloDbContext CreateDb()
    {
        var options = new DbContextOptionsBuilder<PepinilloDbContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString())
            .Options;
        return new PepinilloDbContext(options);
    }

    private static EntitlementService FreeEntitlements()
    {
        var e = new EntitlementService(new StoreCommerceService(new NoAuthBackend()));
        e.ApplyStatus(new SubscriptionStatus { Tier = EntitlementTier.Free });
        return e;
    }

    private static EntitlementService PlusEntitlements()
    {
        var e = new EntitlementService(new StoreCommerceService(new NoAuthBackend()));
        e.ApplyStatus(new SubscriptionStatus { Tier = EntitlementTier.PepinilloPlus });
        return e;
    }

    private static async Task SeedDayAsync(IFocusSessionService sessions, DateTime dayUtc, int seconds = 600)
    {
        await sessions.SaveSessionAsync(new FocusSession
        {
            Mode = FocusMode.Pomodoro,
            ElapsedSeconds = seconds,
            TargetDurationSeconds = 1500,
            IsCompleted = true,
            StartedAt = dayUtc.Date.AddHours(12),
            CompletedAt = dayUtc.Date.AddHours(12).AddSeconds(seconds)
        });
    }

    [Fact]
    public void Entitlement_CanExport_IsPremiumOnly()
    {
        Assert.False(FreeEntitlements().CanExport);
        Assert.True(PlusEntitlements().CanExport);
    }

    [Fact]
    public void ExportService_Csv_HasHeaderAndRow()
    {
        var export = new ExportService();
        var id = Guid.Parse("aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee");
        var taskId = Guid.Parse("11111111-2222-3333-4444-555555555555");
        var started = new DateTime(2026, 8, 1, 10, 0, 0, DateTimeKind.Utc);
        var sessions = new List<FocusSession>
        {
            new()
            {
                Id = id,
                Mode = FocusMode.Pomodoro,
                StartedAt = started,
                CompletedAt = started.AddMinutes(25),
                ElapsedSeconds = 1500,
                TargetDurationSeconds = 1500,
                JournalNote = "Felt good, \"focused\"",
                EnergyRating = 4,
                TaskItemId = taskId,
                IsCompleted = true
            }
        };

        var csv = export.BuildSessionsCsv(sessions);

        Assert.StartsWith("\uFEFFId,Mode,StartedAtUtc,CompletedAtUtc,ElapsedSeconds,TargetDurationSeconds,JournalNote,EnergyRating,TaskItemId", csv);
        Assert.Contains("aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee", csv);
        Assert.Contains("Pomodoro", csv);
        Assert.Contains("2026-08-01T10:00:00Z", csv);
        Assert.Contains("1500", csv);
        Assert.Contains("\"Felt good, \"\"focused\"\"\"", csv);
        Assert.Contains("4", csv);
        Assert.Contains(taskId.ToString(), csv);

        var bytes = ExportService.GetCsvBytes(csv);
        Assert.True(bytes.Length >= 3);
        Assert.Equal(0xEF, bytes[0]);
        Assert.Equal(0xBB, bytes[1]);
        Assert.Equal(0xBF, bytes[2]);
    }

    [Fact]
    public void ExportService_Pdf_IsMinimalPdf()
    {
        var export = new ExportService();
        var sessions = new List<FocusSession>
        {
            new()
            {
                Mode = FocusMode.Flowtime,
                StartedAt = new DateTime(2026, 8, 2, 9, 0, 0, DateTimeKind.Utc),
                ElapsedSeconds = 900,
                TargetDurationSeconds = 1800,
                IsCompleted = true
            }
        };

        var pdf = export.BuildSessionsPdfSimple(sessions);
        var text = Encoding.ASCII.GetString(pdf);

        Assert.StartsWith("%PDF-1.4", text);
        Assert.Contains("%%EOF", text);
        Assert.Contains("Flowtime", text);
        Assert.Contains("/Type /Page", text);
    }

    [Fact]
    public async Task AnalyticsViewModel_Free_ExportRaisesPaywall()
    {
        await using var db = CreateDb();
        var sessions = new FocusSessionService(db);
        await SeedDayAsync(sessions, DateTime.UtcNow.Date);

        var export = new ExportService();
        var entitlements = FreeEntitlements();
        var vm = new AnalyticsViewModel(sessions, entitlements, exportService: export);

        string? requested = null;
        (string Ext, string Name, byte[] Bytes)? file = null;
        vm.PremiumFeatureRequested += (_, f) => requested = f;
        vm.ExportFileReady += (_, args) => file = args;

        await vm.LoadAsync();
        Assert.False(vm.CanExport);

        await vm.ExportCsvCommand.ExecuteAsync(null);

        Assert.Equal("export", requested);
        Assert.Null(file);
        Assert.Contains("Pepinillo+", vm.ExportStatusMessage);
    }

    [Fact]
    public async Task AnalyticsViewModel_Premium_ExportEmitsCsv()
    {
        await using var db = CreateDb();
        var sessions = new FocusSessionService(db);
        var day = DateTime.UtcNow.Date;
        await SeedDayAsync(sessions, day);

        var export = new ExportService();
        var entitlements = PlusEntitlements();
        var vm = new AnalyticsViewModel(sessions, entitlements, exportService: export);

        (string Ext, string Name, byte[] Bytes)? file = null;
        vm.ExportFileReady += (_, args) => file = args;

        await vm.LoadAsync();
        Assert.True(vm.CanExport);

        await vm.ExportCsvCommand.ExecuteAsync(null);

        Assert.NotNull(file);
        Assert.Equal("csv", file!.Value.Ext);
        Assert.EndsWith(".csv", file.Value.Name);
        var csv = Encoding.UTF8.GetString(file.Value.Bytes);
        Assert.Contains("Id,Mode,StartedAtUtc", csv);
        Assert.Contains("Pomodoro", csv);
    }

    [Fact]
    public async Task StreakProtection_Premium_BridgesOneDayGap()
    {
        await using var db = CreateDb();
        var settings = new SettingsService(db);
        var entitlements = PlusEntitlements();
        var protection = new StreakProtectionService(settings, entitlements);
        var sessions = new FocusSessionService(db, protection);

        // Mon 2026-08-03 is a Monday; build: Fri, Sat, (skip Sun), Mon
        var monday = new DateTime(2026, 8, 3, 0, 0, 0, DateTimeKind.Utc);
        await SeedDayAsync(sessions, monday.AddDays(-3)); // Fri
        await SeedDayAsync(sessions, monday.AddDays(-2)); // Sat
        // Sunday missing
        await SeedDayAsync(sessions, monday); // Mon

        var (current, best, applied) = await sessions.GetStreaksAsync(monday);

        Assert.True(applied);
        Assert.Equal(4, current); // Fri+Sat+protected Sun+Mon
        Assert.Equal(2, best); // raw best is Fri-Sat (or Mon alone) without protection

        var status = await protection.GetStatusAsync(monday);
        Assert.True(status.UsedThisWeek);
        Assert.False(status.Available);
    }

    [Fact]
    public async Task StreakProtection_Free_DoesNotBridge()
    {
        await using var db = CreateDb();
        var settings = new SettingsService(db);
        var entitlements = FreeEntitlements();
        var protection = new StreakProtectionService(settings, entitlements);
        var sessions = new FocusSessionService(db, protection);

        var monday = new DateTime(2026, 8, 3, 0, 0, 0, DateTimeKind.Utc);
        await SeedDayAsync(sessions, monday.AddDays(-3));
        await SeedDayAsync(sessions, monday.AddDays(-2));
        await SeedDayAsync(sessions, monday);

        var (current, best, applied) = await sessions.GetStreaksAsync(monday);

        Assert.False(applied);
        Assert.Equal(1, current); // only Monday
        Assert.Equal(2, best);
    }

    [Fact]
    public async Task StreakProtection_SecondGapSameWeek_DoesNotBridge()
    {
        await using var db = CreateDb();
        var settings = new SettingsService(db);
        var entitlements = PlusEntitlements();
        var protection = new StreakProtectionService(settings, entitlements);
        var sessions = new FocusSessionService(db, protection);

        // Same ISO week (Mon 8/3–Sun 8/9): Mon, Wed, Fri active; Tue + Thu missing.
        // Walk from Fri: Fri → bridge Thu → Wed → Tue (second gap same week) stops.
        var friday = new DateTime(2026, 8, 7, 0, 0, 0, DateTimeKind.Utc);
        await SeedDayAsync(sessions, friday.AddDays(-4)); // Mon 8/3
        await SeedDayAsync(sessions, friday.AddDays(-2)); // Wed 8/5
        await SeedDayAsync(sessions, friday); // Fri 8/7

        var (current, _, applied) = await sessions.GetStreaksAsync(friday);

        Assert.True(applied);
        Assert.Equal(3, current); // Fri + protected Thu + Wed

        var s = await settings.GetSettingsAsync();
        Assert.Equal(1, s.StreakProtectionUsesThisWeek);
    }

    [Fact]
    public async Task StreakProtection_CanUseSkip_ResetsNextIsoWeek()
    {
        await using var db = CreateDb();
        var settingsService = new SettingsService(db);
        var entitlements = PlusEntitlements();
        var protection = new StreakProtectionService(settingsService, entitlements);

        var monday = new DateTime(2026, 8, 3, 12, 0, 0, DateTimeKind.Utc);
        Assert.True(await protection.CanUseSkipAsync(monday));
        Assert.True(await protection.TryConsumeSkipAsync(monday));
        Assert.False(await protection.CanUseSkipAsync(monday));

        var nextMonday = monday.AddDays(7);
        Assert.True(await protection.CanUseSkipAsync(nextMonday));
    }

    [Fact]
    public void StreakProtection_IsoWeekStart_IsMonday()
    {
        var protection = new StreakProtectionService(
            new SettingsService(CreateDb()),
            PlusEntitlements());

        // Sunday 2026-08-09 → week starts Monday 2026-08-03
        var sunday = new DateTime(2026, 8, 9, 15, 0, 0, DateTimeKind.Utc);
        Assert.Equal(new DateTime(2026, 8, 3), protection.GetIsoWeekStartUtc(sunday));

        // Monday stays Monday
        var monday = new DateTime(2026, 8, 3, 1, 0, 0, DateTimeKind.Utc);
        Assert.Equal(new DateTime(2026, 8, 3), protection.GetIsoWeekStartUtc(monday));
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
            IEnumerable<FocusSession> sessions,
            DateTime? lastSyncAt = null) =>
            Task.FromResult(new Pepinillo.Core.Models.Sync.SessionSyncClientResult { Success = false });
        public Task<Pepinillo.Core.Models.Sync.FullSyncClientResult> PullSessionsAsync(
            int limit = 100, string? sessionCursor = null) =>
            Task.FromResult(new Pepinillo.Core.Models.Sync.FullSyncClientResult { Success = false });
        public Task<SubscriptionStatus> GetSubscriptionStatusAsync() =>
            Task.FromResult(new SubscriptionStatus { Tier = EntitlementTier.Free });
    }
}
