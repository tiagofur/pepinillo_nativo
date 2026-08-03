using System;
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
        await service.SaveSettingsAsync(settings);

        // New service instance (fresh cache) on same DB
        var service2 = new SettingsService(db);
        // Clear by using same db tracked entity - force reload via new context
        await using var db2 = CreateDb();
        // Seed from first db is isolated - use same db without cache:
        var reload = await db.UserSettings.AsNoTracking().FirstAsync();
        Assert.Equal(40, reload.PomodoroFocusMinutes);
        Assert.True(reload.AutoStartBreaks);
        Assert.Equal("Dark", reload.SelectedTheme);
    }

    [Fact]
    public async Task FocusSession_Save_ShouldPersistCompletedSession()
    {
        await using var db = CreateDb();
        var service = new FocusSessionService(db);
        var taskId = Guid.NewGuid();

        var session = new FocusSession
        {
            Mode = FocusMode.Pomodoro,
            TargetDurationSeconds = 1500,
            ElapsedSeconds = 1500,
            TaskItemId = taskId,
            StartedAt = DateTime.UtcNow.AddMinutes(-25),
            CompletedAt = DateTime.UtcNow,
            IsCompleted = true
        };

        await service.SaveSessionAsync(session);

        var recent = await service.GetRecentSessionsAsync();
        Assert.Single(recent);
        Assert.Equal(taskId, recent[0].TaskItemId);
        Assert.True(recent[0].IsCompleted);

        var minutes = await service.GetTodayFocusMinutesAsync();
        Assert.Equal(25, minutes);
    }

    [Fact]
    public async Task TaskService_CreateSubtask_ShouldLinkParent()
    {
        await using var db = CreateDb();
        var service = new TaskService(db);

        var parent = await service.CreateTaskAsync("Parent", estimatedMinutes: 30);
        var child = await service.CreateTaskAsync("Child", parentTaskId: parent.Id);

        var all = await service.GetAllTasksAsync();
        var loadedParent = Assert.Single(all, t => t.Id == parent.Id);
        Assert.Contains(loadedParent.SubTasks, s => s.Id == child.Id);
    }
}
