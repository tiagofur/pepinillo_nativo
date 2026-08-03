using System;
using System.Threading.Tasks;
using Microsoft.EntityFrameworkCore;
using Pepinillo.Core.Data;
using Pepinillo.Core.Services;
using Xunit;

namespace Pepinillo.Core.Tests;

public class TaskServiceTests
{
    private PepinilloDbContext CreateInMemoryDbContext()
    {
        var options = new DbContextOptionsBuilder<PepinilloDbContext>()
            .UseInMemoryDatabase(databaseName: Guid.NewGuid().ToString())
            .Options;

        return new PepinilloDbContext(options);
    }

    [Fact]
    public async Task CreateTask_ShouldAddTaskToDatabase()
    {
        using var dbContext = CreateInMemoryDbContext();
        var service = new TaskService(dbContext);

        var task = await service.CreateTaskAsync("Escribir documentación", estimatedMinutes: 45);

        Assert.NotNull(task);
        Assert.Equal("Escribir documentación", task.Title);
        Assert.Equal(45, task.EstimatedMinutes);
        Assert.False(task.IsCompleted);
    }

    [Fact]
    public async Task ToggleTaskCompletion_ShouldSwitchState()
    {
        using var dbContext = CreateInMemoryDbContext();
        var service = new TaskService(dbContext);

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
        var service = new TaskService(dbContext);

        await service.CreateTaskAsync("Tarea de Hoy", dueDate: DateTime.UtcNow.Date);
        await service.CreateTaskAsync("Tarea de Mañana", dueDate: DateTime.UtcNow.Date.AddDays(1));

        var todayTasks = await service.GetTodayTasksAsync();

        Assert.Single(todayTasks);
        Assert.Equal("Tarea de Hoy", todayTasks[0].Title);
    }
}
