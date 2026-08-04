using System;
using System.Linq;
using System.Threading.Tasks;
using Microsoft.EntityFrameworkCore;
using Pepinillo.Core.Data;
using Pepinillo.Core.Models;
using Pepinillo.Core.Services;
using Pepinillo.Core.ViewModels;
using Xunit;

namespace Pepinillo.Core.Tests;

public class ReflectServiceTests
{
    private static PepinilloDbContext CreateDb()
    {
        var options = new DbContextOptionsBuilder<PepinilloDbContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString())
            .Options;
        return new PepinilloDbContext(options);
    }

    private static ReflectService CreateReflect(PepinilloDbContext db)
    {
        var sessions = new FocusSessionService(db);
        return new ReflectService(db, sessions);
    }

    private static async Task SeedCompletedAsync(
        FocusSessionService sessions,
        FocusMode mode,
        int elapsedSeconds,
        DateTime startedAtUtc)
    {
        await sessions.SaveSessionAsync(new FocusSession
        {
            Mode = mode,
            ElapsedSeconds = elapsedSeconds,
            IsCompleted = true,
            StartedAt = startedAtUtc,
            CompletedAt = startedAtUtc.AddSeconds(elapsedSeconds)
        });
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

    [Fact]
    public async Task FirstSession_UnlocksAtOneCompleted_NotAtZero()
    {
        await using var db = CreateDb();
        var sessions = new FocusSessionService(db);
        var reflect = CreateReflect(db);
        var now = new DateTime(2026, 8, 4, 12, 0, 0, DateTimeKind.Utc);

        var empty = await reflect.GetAchievementsAsync(now);
        var first = empty.Single(a => a.Id == "first_session");
        Assert.False(first.IsUnlocked);
        Assert.Equal(0, first.ProgressCurrent);

        await SeedCompletedAsync(sessions, FocusMode.Pomodoro, 60, now.AddHours(-1));
        var after = await reflect.GetAchievementsAsync(now);
        first = after.Single(a => a.Id == "first_session");
        Assert.True(first.IsUnlocked);
        Assert.Equal(1, first.ProgressCurrent);
        Assert.Equal(1.0, first.ProgressRatio);
    }

    [Fact]
    public async Task FirstSession_IgnoresZeroElapsedCompleted()
    {
        await using var db = CreateDb();
        var sessions = new FocusSessionService(db);
        var reflect = CreateReflect(db);
        var now = new DateTime(2026, 8, 4, 12, 0, 0, DateTimeKind.Utc);

        await sessions.SaveSessionAsync(new FocusSession
        {
            Mode = FocusMode.Stopwatch,
            ElapsedSeconds = 0,
            IsCompleted = true,
            StartedAt = now
        });

        var achievements = await reflect.GetAchievementsAsync(now);
        Assert.False(achievements.Single(a => a.Id == "first_session").IsUnlocked);
    }

    [Fact]
    public async Task WeeklyStreak_UnlocksAt7Days_NotAt6()
    {
        await using var db = CreateDb();
        var sessions = new FocusSessionService(db);
        var reflect = CreateReflect(db);
        var today = new DateTime(2026, 8, 4, 0, 0, 0, DateTimeKind.Utc); // Tuesday

        // 6 consecutive days ending today
        for (var i = 5; i >= 0; i--)
        {
            await SeedCompletedAsync(sessions, FocusMode.Pomodoro, 300, today.AddDays(-i).AddHours(10));
        }

        var six = await reflect.GetAchievementsAsync(today);
        var streak = six.Single(a => a.Id == "weekly_streak");
        Assert.False(streak.IsUnlocked);
        Assert.Equal(6, streak.ProgressCurrent);
        Assert.Equal(7, streak.ProgressTarget);

        await SeedCompletedAsync(sessions, FocusMode.Pomodoro, 300, today.AddDays(-6).AddHours(10));
        var seven = await reflect.GetAchievementsAsync(today);
        streak = seven.Single(a => a.Id == "weekly_streak");
        Assert.True(streak.IsUnlocked);
        Assert.Equal(7, streak.ProgressCurrent);
    }

    [Fact]
    public async Task PomodoroMaster_UnlocksAt100_NotAt99()
    {
        await using var db = CreateDb();
        var sessions = new FocusSessionService(db);
        var reflect = CreateReflect(db);
        var day = new DateTime(2026, 1, 1, 12, 0, 0, DateTimeKind.Utc);

        for (var i = 0; i < 99; i++)
        {
            await SeedCompletedAsync(sessions, FocusMode.Pomodoro, 60, day.AddMinutes(i));
        }

        var almost = await reflect.GetAchievementsAsync(day);
        var master = almost.Single(a => a.Id == "pomodoro_master");
        Assert.False(master.IsUnlocked);
        Assert.Equal(99, master.ProgressCurrent);

        await SeedCompletedAsync(sessions, FocusMode.Pomodoro, 60, day.AddMinutes(100));
        var done = await reflect.GetAchievementsAsync(day);
        master = done.Single(a => a.Id == "pomodoro_master");
        Assert.True(master.IsUnlocked);
        Assert.Equal(100, master.ProgressCurrent);
    }

    [Fact]
    public async Task DeepDiver_UnlocksAt10FlowtimeHours()
    {
        await using var db = CreateDb();
        var sessions = new FocusSessionService(db);
        var reflect = CreateReflect(db);
        var day = new DateTime(2026, 3, 1, 12, 0, 0, DateTimeKind.Utc);

        // 9 hours Flowtime (32400s) — not unlocked
        await SeedCompletedAsync(sessions, FocusMode.Flowtime, 9 * 3600, day);
        var under = await reflect.GetAchievementsAsync(day);
        var diver = under.Single(a => a.Id == "deep_diver");
        Assert.False(diver.IsUnlocked);
        Assert.Equal(9, diver.ProgressCurrent);
        Assert.Equal(10, diver.ProgressTarget);

        await SeedCompletedAsync(sessions, FocusMode.Flowtime, 3600, day.AddHours(1));
        var over = await reflect.GetAchievementsAsync(day);
        diver = over.Single(a => a.Id == "deep_diver");
        Assert.True(diver.IsUnlocked);
        Assert.Equal(10, diver.ProgressCurrent);
    }

    [Fact]
    public async Task CenturyClub_UnlocksAt100TotalSessions()
    {
        await using var db = CreateDb();
        var sessions = new FocusSessionService(db);
        var reflect = CreateReflect(db);
        var day = new DateTime(2026, 2, 1, 8, 0, 0, DateTimeKind.Utc);

        for (var i = 0; i < 99; i++)
        {
            var mode = i % 2 == 0 ? FocusMode.Stopwatch : FocusMode.Pomodoro;
            await SeedCompletedAsync(sessions, mode, 30, day.AddMinutes(i));
        }

        var almost = await reflect.GetAchievementsAsync(day);
        Assert.False(almost.Single(a => a.Id == "century_club").IsUnlocked);

        await SeedCompletedAsync(sessions, FocusMode.TimeBlocking, 30, day.AddMinutes(200));
        var done = await reflect.GetAchievementsAsync(day);
        Assert.True(done.Single(a => a.Id == "century_club").IsUnlocked);
    }

    [Fact]
    public async Task EarlyBird_UsesUtcHourBefore7()
    {
        await using var db = CreateDb();
        var sessions = new FocusSessionService(db);
        var reflect = CreateReflect(db);
        var day = new DateTime(2026, 5, 1, 12, 0, 0, DateTimeKind.Utc);

        // 10 sessions at 06:59 UTC — count
        for (var i = 0; i < 10; i++)
        {
            await SeedCompletedAsync(
                sessions,
                FocusMode.Pomodoro,
                60,
                new DateTime(2026, 5, 1, 6, 59, 0, DateTimeKind.Utc).AddDays(-i));
        }

        // 5 sessions at 07:00 UTC — do NOT count (hour is not < 7)
        for (var i = 0; i < 5; i++)
        {
            await SeedCompletedAsync(
                sessions,
                FocusMode.Pomodoro,
                60,
                new DateTime(2026, 4, 1, 7, 0, 0, DateTimeKind.Utc).AddDays(-i));
        }

        var achievements = await reflect.GetAchievementsAsync(day);
        var bird = achievements.Single(a => a.Id == "early_bird");
        Assert.True(bird.IsUnlocked);
        Assert.Equal(10, bird.ProgressCurrent);
        Assert.Equal(ReflectService.EarlyBirdUtcHourExclusive, 7);
    }

    [Fact]
    public async Task EarlyBird_NotUnlockedAt9Sessions()
    {
        await using var db = CreateDb();
        var sessions = new FocusSessionService(db);
        var reflect = CreateReflect(db);
        var day = new DateTime(2026, 5, 10, 12, 0, 0, DateTimeKind.Utc);

        for (var i = 0; i < 9; i++)
        {
            await SeedCompletedAsync(
                sessions,
                FocusMode.Pomodoro,
                60,
                new DateTime(2026, 5, 1, 5, 0, 0, DateTimeKind.Utc).AddDays(-i));
        }

        var bird = (await reflect.GetAchievementsAsync(day)).Single(a => a.Id == "early_bird");
        Assert.False(bird.IsUnlocked);
        Assert.Equal(9, bird.ProgressCurrent);
    }

    [Fact]
    public void GetUtcWeekStartMonday_IsMondayInclusive()
    {
        // Wednesday 2026-08-05 → week starts Monday 2026-08-03
        var wed = new DateTime(2026, 8, 5, 15, 0, 0, DateTimeKind.Utc);
        var start = ReflectService.GetUtcWeekStartMonday(wed);
        Assert.Equal(new DateTime(2026, 8, 3, 0, 0, 0, DateTimeKind.Utc), start);
        Assert.Equal(DayOfWeek.Monday, start.DayOfWeek);

        // Monday stays Monday
        var mon = new DateTime(2026, 8, 3, 1, 0, 0, DateTimeKind.Utc);
        Assert.Equal(new DateTime(2026, 8, 3, 0, 0, 0, DateTimeKind.Utc), ReflectService.GetUtcWeekStartMonday(mon));

        // Sunday belongs to week starting previous Monday
        var sun = new DateTime(2026, 8, 9, 23, 0, 0, DateTimeKind.Utc);
        Assert.Equal(new DateTime(2026, 8, 3, 0, 0, 0, DateTimeKind.Utc), ReflectService.GetUtcWeekStartMonday(sun));
    }

    [Fact]
    public void ComputeTrend_UpDownFlat()
    {
        Assert.Equal(1, ReflectService.ComputeTrend(5.0, 3.0));
        Assert.Equal(-1, ReflectService.ComputeTrend(2.0, 4.0));
        Assert.Equal(0, ReflectService.ComputeTrend(3.0, 3.0));
        Assert.Equal(0, ReflectService.ComputeTrend(3.02, 3.0)); // within epsilon
    }

    [Fact]
    public async Task WeeklyReview_ComparesThisWeekVsPrevious_WithTrend()
    {
        await using var db = CreateDb();
        var sessions = new FocusSessionService(db);
        var reflect = CreateReflect(db);

        // Wednesday of week starting Mon 2026-08-03
        var now = new DateTime(2026, 8, 5, 12, 0, 0, DateTimeKind.Utc);
        var thisWeekMon = new DateTime(2026, 8, 3, 0, 0, 0, DateTimeKind.Utc);
        var prevWeekMon = new DateTime(2026, 7, 27, 0, 0, 0, DateTimeKind.Utc);

        // Previous week: 1h Pomodoro
        await SeedCompletedAsync(sessions, FocusMode.Pomodoro, 3600, prevWeekMon.AddHours(10));
        // This week: 2h Flowtime
        await SeedCompletedAsync(sessions, FocusMode.Flowtime, 7200, thisWeekMon.AddHours(11));

        var review = await reflect.GetWeeklyReviewAsync(now, includeDetails: true);

        Assert.False(review.IsLocked);
        Assert.Equal("This week", review.Label);
        Assert.Equal(thisWeekMon, review.PeriodStartUtc);
        Assert.Equal(2.0, review.FocusHours);
        Assert.Equal(1, review.SessionCount);
        Assert.Equal("Flowtime", review.TopModeName);
        Assert.Equal(1.0, review.PreviousFocusHours);
        Assert.Equal(1, review.PreviousSessionCount);
        Assert.Equal(1, review.TrendVsPrevious); // up
    }

    [Fact]
    public async Task MonthlyReview_ComparesCalendarMonthsUtc()
    {
        await using var db = CreateDb();
        var sessions = new FocusSessionService(db);
        var reflect = CreateReflect(db);
        var now = new DateTime(2026, 8, 15, 12, 0, 0, DateTimeKind.Utc);

        await SeedCompletedAsync(sessions, FocusMode.Pomodoro, 1800, new DateTime(2026, 7, 10, 9, 0, 0, DateTimeKind.Utc));
        await SeedCompletedAsync(sessions, FocusMode.Stopwatch, 3600, new DateTime(2026, 8, 2, 9, 0, 0, DateTimeKind.Utc));
        await SeedCompletedAsync(sessions, FocusMode.Stopwatch, 3600, new DateTime(2026, 8, 3, 9, 0, 0, DateTimeKind.Utc));

        var review = await reflect.GetMonthlyReviewAsync(now, includeDetails: true);

        Assert.Equal(new DateTime(2026, 8, 1, 0, 0, 0, DateTimeKind.Utc), review.PeriodStartUtc);
        Assert.Equal(2.0, review.FocusHours);
        Assert.Equal(2, review.SessionCount);
        Assert.Equal("Stopwatch", review.TopModeName);
        Assert.Equal(0.5, review.PreviousFocusHours);
        Assert.Equal(1, review.TrendVsPrevious);
    }

    [Fact]
    public async Task WeeklyReview_LockedTeaser_WhenIncludeDetailsFalse()
    {
        await using var db = CreateDb();
        var sessions = new FocusSessionService(db);
        var reflect = CreateReflect(db);
        var now = new DateTime(2026, 8, 5, 12, 0, 0, DateTimeKind.Utc);
        await SeedCompletedAsync(sessions, FocusMode.Pomodoro, 3600, now);

        var review = await reflect.GetWeeklyReviewAsync(now, includeDetails: false);

        Assert.True(review.IsLocked);
        Assert.Contains("Upgrade", review.TeaserMessage);
        Assert.Equal(0, review.FocusHours);
        Assert.Equal(0, review.SessionCount);
    }

    [Fact]
    public async Task AnalyticsViewModel_Free_ShowsReviewTeaser_AndAchievements()
    {
        await using var db = CreateDb();
        var sessions = new FocusSessionService(db);
        var reflect = CreateReflect(db);
        var now = DateTime.UtcNow;
        await SeedCompletedAsync(sessions, FocusMode.Pomodoro, 600, now.Date.AddHours(10));

        var vm = new AnalyticsViewModel(sessions, FreeEntitlements(), reflect);
        await vm.LoadAsync();

        Assert.False(vm.CanViewPeriodReviews);
        Assert.True(vm.ShowReviewPaywallTeaser);
        Assert.NotNull(vm.WeeklyReview);
        Assert.True(vm.WeeklyReview!.IsLocked);
        Assert.NotNull(vm.MonthlyReview);
        Assert.True(vm.MonthlyReview!.IsLocked);
        Assert.Equal(6, vm.Achievements.Count);
        Assert.Contains(vm.Achievements, a => a.Id == "first_session" && a.IsUnlocked);
    }

    [Fact]
    public async Task AnalyticsViewModel_Premium_LoadsReviewDetails()
    {
        await using var db = CreateDb();
        var sessions = new FocusSessionService(db);
        var reflect = CreateReflect(db);
        var now = DateTime.UtcNow;
        await SeedCompletedAsync(sessions, FocusMode.Pomodoro, 3600, now.Date.AddHours(9));

        var vm = new AnalyticsViewModel(sessions, PlusEntitlements(), reflect);
        await vm.LoadAsync();

        Assert.True(vm.CanViewPeriodReviews);
        Assert.False(vm.ShowReviewPaywallTeaser);
        Assert.NotNull(vm.WeeklyReview);
        Assert.False(vm.WeeklyReview!.IsLocked);
        Assert.True(vm.WeeklyReview.SessionCount >= 1);
        Assert.False(vm.MonthlyReview!.IsLocked);
    }

    [Fact]
    public async Task AnalyticsViewModel_OpenReviewPaywall_RaisesEvent()
    {
        await using var db = CreateDb();
        var sessions = new FocusSessionService(db);
        var reflect = CreateReflect(db);
        var vm = new AnalyticsViewModel(sessions, FreeEntitlements(), reflect);
        string? requested = null;
        vm.PremiumFeatureRequested += (_, feature) => requested = feature;

        vm.OpenReviewPaywallCommand.Execute(null);

        Assert.Equal("period_review", requested);
    }

    [Fact]
    public async Task Achievements_AlwaysSixDefinitions()
    {
        await using var db = CreateDb();
        var reflect = CreateReflect(db);
        var list = await reflect.GetAchievementsAsync();
        Assert.Equal(6, list.Count);
        Assert.Equal(
            new[] { "first_session", "weekly_streak", "pomodoro_master", "deep_diver", "century_club", "early_bird" },
            list.Select(a => a.Id).ToArray());
    }

    private sealed class NoAuthBackend : IBackendApiClient
    {
        public bool IsAuthenticated => false;
        public string? AuthToken => null;
        public Task InitializeAsync() => Task.CompletedTask;
        public Task<bool> LoginAsync(string email, string password) => Task.FromResult(false);
        public Task<bool> RegisterAsync(string email, string password, string name) => Task.FromResult(false);
        public Task<bool> RefreshAsync() => Task.FromResult(false);
        public Task LogoutAsync() => Task.CompletedTask;
        public Task<bool> SyncSessionsAsync(System.Collections.Generic.IEnumerable<FocusSession> sessions) =>
            Task.FromResult(false);
        public Task<SubscriptionStatus> GetSubscriptionStatusAsync() =>
            Task.FromResult(new SubscriptionStatus { Tier = EntitlementTier.Free });
    }
}
