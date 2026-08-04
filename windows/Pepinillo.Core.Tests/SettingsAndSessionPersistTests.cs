using System;
using System.Linq;
using System.Threading.Tasks;
using Microsoft.EntityFrameworkCore;
using Pepinillo.Core.Data;
using Pepinillo.Core.Models;
using Pepinillo.Core.Services;
using Xunit;

namespace Pepinillo.Core.Tests;

public class SettingsAndSessionPersistTests
{
    private static PepinilloDbContext CreateDb()
    {
        var options = new DbContextOptionsBuilder<PepinilloDbContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString())
            .Options;
        return new PepinilloDbContext(options);
    }

    [Fact]
    public async Task Settings_Get_ShouldCreateDefaults()
    {
        await using var db = CreateDb();
        var service = new SettingsService(db);

        var settings = await service.GetSettingsAsync();

        Assert.Equal(1, settings.Id);
        Assert.Equal(25, settings.PomodoroFocusMinutes);
        Assert.Equal("System", settings.SelectedTheme);
        Assert.Equal(60, settings.TimeBlockingMinutes);
        Assert.Equal("en", settings.PreferredLanguage);
    }

    [Fact]
    public async Task Settings_Save_ShouldRoundTrip()
    {
        await using var db = CreateDb();
        var service = new SettingsService(db);

        var settings = await service.GetSettingsAsync();
        settings.PomodoroFocusMinutes = 40;
        settings.AutoStartBreaks = true;
        settings.SelectedTheme = "Dark";
        settings.PreferredLanguage = "es";
        settings.TimeBlockingMinutes = 90;
        settings.LaunchAtWindowsStartup = true;
        settings.PlayPauseHotkey = "Ctrl+Alt+P";
        await service.SaveSettingsAsync(settings);

        var reload = await db.UserSettings.AsNoTracking().FirstAsync();
        Assert.Equal(40, reload.PomodoroFocusMinutes);
        Assert.True(reload.AutoStartBreaks);
        Assert.Equal("Dark", reload.SelectedTheme);
        Assert.Equal("es", reload.PreferredLanguage);
        Assert.Equal(90, reload.TimeBlockingMinutes);
        Assert.True(reload.LaunchAtWindowsStartup);
        Assert.Equal("Ctrl+Alt+P", reload.PlayPauseHotkey);
    }

    [Fact]
    public async Task Settings_LaunchAtWindowsStartup_DefaultsFalse()
    {
        await using var db = CreateDb();
        var service = new SettingsService(db);
        var settings = await service.GetSettingsAsync();
        Assert.False(settings.LaunchAtWindowsStartup);
    }

    [Fact]
    public async Task FocusSession_Save_ShouldPersistCompletedSession()
    {
        await using var db = CreateDb();
        var service = new FocusSessionService(db);
        var taskId = Guid.NewGuid();

        var started = DateTime.UtcNow.Date.AddHours(10);
        var session = new FocusSession
        {
            Mode = FocusMode.Pomodoro,
            TargetDurationSeconds = 1500,
            ElapsedSeconds = 1500,
            TaskItemId = taskId,
            StartedAt = started,
            CompletedAt = started.AddMinutes(25),
            IsCompleted = true
        };

        await service.SaveSessionAsync(session);

        var recent = await service.GetRecentSessionsAsync();
        Assert.Single(recent);
        Assert.Equal(taskId, recent[0].TaskItemId);
        Assert.True(recent[0].IsCompleted);

        var minutes = await service.GetTodayFocusMinutesAsync(started);
        Assert.Equal(25, minutes);
    }

    [Fact]
    public async Task FocusSession_JournalFields_ShouldPersist()
    {
        await using var db = CreateDb();
        var service = new FocusSessionService(db);
        var session = new FocusSession
        {
            Mode = FocusMode.Flowtime,
            ElapsedSeconds = 900,
            IsCompleted = true,
            StartedAt = DateTime.UtcNow.Date.AddHours(8)
        };
        await service.SaveSessionAsync(session);
        await service.UpdateJournalAsync(session.Id, "Felt focused", 5);

        var loaded = await db.FocusSessions.FindAsync(session.Id);
        Assert.Equal("Felt focused", loaded!.JournalNote);
        Assert.Equal(5, loaded.EnergyRating);
        Assert.False(loaded.IsSynced);
    }

    [Fact]
    public async Task Analytics_Streaks_ShouldCountConsecutiveUtcDays()
    {
        await using var db = CreateDb();
        var service = new FocusSessionService(db);
        var today = new DateTime(2026, 8, 3, 0, 0, 0, DateTimeKind.Utc);

        // Day -2, -1, today
        for (var i = 2; i >= 0; i--)
        {
            await service.SaveSessionAsync(new FocusSession
            {
                Mode = FocusMode.Pomodoro,
                ElapsedSeconds = 600,
                IsCompleted = true,
                StartedAt = today.AddDays(-i).AddHours(12)
            });
        }

        var (current, best, protection) = await service.GetStreaksAsync(today);
        Assert.Equal(3, current);
        Assert.Equal(3, best);
        Assert.False(protection);
    }

    [Fact]
    public async Task Analytics_ModeBreakdown_AndRangeQueries()
    {
        await using var db = CreateDb();
        var service = new FocusSessionService(db);
        var day = new DateTime(2026, 8, 1, 0, 0, 0, DateTimeKind.Utc);

        await service.SaveSessionAsync(new FocusSession
        {
            Mode = FocusMode.Pomodoro,
            ElapsedSeconds = 1500,
            IsCompleted = true,
            StartedAt = day.AddHours(9)
        });
        await service.SaveSessionAsync(new FocusSession
        {
            Mode = FocusMode.Flowtime,
            ElapsedSeconds = 3000,
            IsCompleted = true,
            StartedAt = day.AddHours(14)
        });

        var total = await service.GetTotalFocusSecondsAsync(day, day.AddDays(1));
        Assert.Equal(4500, total);

        var breakdown = await service.GetModeBreakdownAsync(day, day.AddDays(1));
        Assert.Equal(2, breakdown.Count);
        Assert.Equal(FocusMode.Flowtime, breakdown[0].Mode);
        Assert.Equal(3000, breakdown[0].TotalSeconds);
        Assert.True(breakdown[0].FractionOfMax >= breakdown[1].FractionOfMax);
    }

    [Fact]
    public async Task TaskService_CreateSubtask_ShouldLinkParent()
    {
        await using var db = CreateDb();
        var entitlements = new EntitlementService(new StoreCommerceService(new NoOpBackend()));
        entitlements.ApplyStatus(new SubscriptionStatus { Tier = EntitlementTier.PepinilloPlus });
        var service = new TaskService(db, entitlements);

        var parent = await service.CreateTaskAsync("Parent", estimatedMinutes: 30);
        var child = await service.CreateTaskAsync("Child", parentTaskId: parent.Id);

        var all = await service.GetAllTasksAsync();
        var loadedParent = Assert.Single(all, t => t.Id == parent.Id);
        Assert.Contains(loadedParent.SubTasks, s => s.Id == child.Id);
    }

    [Fact]
    public void LocalizationService_ReturnsSpanishForEs()
    {
        var loc = new LocalizationService();
        loc.SetLanguage("es");
        Assert.Equal("Configuración", loc.GetString("Settings.Title"));
        loc.SetLanguage("pt");
        Assert.Equal("Configurações", loc.GetString("Settings.Title"));
        loc.SetLanguage("en");
        Assert.Equal("Settings", loc.GetString("Settings.Title"));
    }

    [Fact]
    public void SoundscapeCatalog_UsesEnglishNames()
    {
        var audio = new AudioPlayerService();
        var tracks = audio.GetAvailableSoundscapes();
        Assert.Contains(tracks, t => t.Name == "Rain");
        Assert.Contains(tracks, t => t.Name == "Deep Space");
        Assert.Contains(tracks, t => t.IsPremium);
        Assert.Equal(4, tracks.Count(t => !t.IsPremium));
        Assert.Equal(3, tracks.Count(t => t.IsPremium));
    }

    [Fact]
    public async Task Settings_SoundscapeAutoPlayFields_RoundTrip()
    {
        await using var db = CreateDb();
        var service = new SettingsService(db);

        var settings = await service.GetSettingsAsync();
        Assert.True(settings.EnableSoundscapes);
        Assert.True(settings.AutoPlaySoundscapeOnFocus);
        Assert.Equal("rain", settings.PreferredSoundscapeId);

        settings.AutoPlaySoundscapeOnFocus = false;
        settings.PreferredSoundscapeId = "cafe";
        settings.SoundscapesMasterVolume = 0.42;
        await service.SaveSettingsAsync(settings);

        var reload = await db.UserSettings.AsNoTracking().FirstAsync();
        Assert.False(reload.AutoPlaySoundscapeOnFocus);
        Assert.Equal("cafe", reload.PreferredSoundscapeId);
        Assert.Equal(0.42, reload.SoundscapesMasterVolume);
    }

    private sealed class NoOpBackend : IBackendApiClient
    {
        public bool IsAuthenticated => false;
        public string? AuthToken => null;
        public int? LastStatusCode => null;
        public string? LastError => null;
        public System.Threading.Tasks.Task InitializeAsync() => System.Threading.Tasks.Task.CompletedTask;
        public System.Threading.Tasks.Task<bool> LoginAsync(string email, string password) =>
            System.Threading.Tasks.Task.FromResult(false);
        public System.Threading.Tasks.Task<bool> RegisterAsync(string email, string password, string name) =>
            System.Threading.Tasks.Task.FromResult(false);
        public System.Threading.Tasks.Task<bool> RefreshAsync() => System.Threading.Tasks.Task.FromResult(false);
        public System.Threading.Tasks.Task LogoutAsync() => System.Threading.Tasks.Task.CompletedTask;
        public System.Threading.Tasks.Task<Pepinillo.Core.Models.Sync.SessionSyncClientResult> SyncSessionsAsync(
            System.Collections.Generic.IEnumerable<FocusSession> sessions,
            System.DateTime? lastSyncAt = null) =>
            System.Threading.Tasks.Task.FromResult(new Pepinillo.Core.Models.Sync.SessionSyncClientResult { Success = false });
        public System.Threading.Tasks.Task<Pepinillo.Core.Models.Sync.FullSyncClientResult> PullSessionsAsync(
            int limit = 100, string? sessionCursor = null) =>
            System.Threading.Tasks.Task.FromResult(new Pepinillo.Core.Models.Sync.FullSyncClientResult { Success = false });
        public System.Threading.Tasks.Task<SubscriptionStatus> GetSubscriptionStatusAsync() =>
            System.Threading.Tasks.Task.FromResult(new SubscriptionStatus { Tier = EntitlementTier.Free });
    }
}
