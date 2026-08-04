using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Microsoft.EntityFrameworkCore;
using Pepinillo.Core.Data;
using Pepinillo.Core.Models;

namespace Pepinillo.Core.Services;

public class TaskService : ITaskService
{
    private readonly PepinilloDbContext _dbContext;

    public TaskService(PepinilloDbContext dbContext)
    {
        _dbContext = dbContext;
    }

    public async Task<List<TaskItem>> GetAllTasksAsync()
    {
        return await _dbContext.TaskItems
            .Include(t => t.SubTasks)
            .Where(t => t.ParentTaskId == null)
            .OrderByDescending(t => t.Priority)
            .ThenByDescending(t => t.CreatedAt)
            .ToListAsync();
    }

    public async Task<List<TaskItem>> GetTodayTasksAsync()
    {
        var today = DateTime.UtcNow.Date;
        return await _dbContext.TaskItems
            .Include(t => t.SubTasks)
            .Where(t => t.ParentTaskId == null
                        && t.DueDate.HasValue
                        && t.DueDate.Value.Date <= today
                        && !t.IsCompleted)
            .OrderByDescending(t => t.Priority)
            .ThenBy(t => t.DueDate)
            .ToListAsync();
    }

    public async Task<List<TaskItem>> GetUpcomingTasksAsync()
    {
        var tomorrow = DateTime.UtcNow.Date.AddDays(1);
        return await _dbContext.TaskItems
            .Include(t => t.SubTasks)
            .Where(t => t.ParentTaskId == null
                        && t.DueDate.HasValue
                        && t.DueDate.Value.Date >= tomorrow
                        && !t.IsCompleted)
            .OrderByDescending(t => t.Priority)
            .ThenBy(t => t.DueDate)
            .ToListAsync();
    }

    public async Task<List<TaskItem>> GetInboxTasksAsync()
    {
        return await _dbContext.TaskItems
            .Include(t => t.SubTasks)
            .Where(t => !t.DueDate.HasValue && !t.IsCompleted && !t.ParentTaskId.HasValue)
            .OrderByDescending(t => t.Priority)
            .ThenByDescending(t => t.CreatedAt)
            .ToListAsync();
    }

    public async Task<TaskItem> CreateTaskAsync(
        string title,
        string? description = null,
        int estimatedMinutes = 25,
        DateTime? dueDate = null,
        Guid? parentTaskId = null,
        int priority = 0,
        string energyLevel = "",
        string? recurrenceRule = null,
        int estimatedPomodoros = 0)
    {
        if (string.IsNullOrWhiteSpace(title))
            throw new ArgumentException("Title cannot be empty", nameof(title));

        var normalizedEnergy = NormalizeEnergy(energyLevel);
        var normalizedRecurrence = NormalizeRecurrence(recurrenceRule);
        var clampedPriority = Math.Clamp(priority, 0, 3);

        var pomodoros = estimatedPomodoros > 0
            ? estimatedPomodoros
            : Math.Max(1, (int)Math.Ceiling(estimatedMinutes / 25.0));

        var task = new TaskItem
        {
            Id = Guid.NewGuid(),
            Title = title.Trim(),
            Description = description,
            EstimatedMinutes = estimatedMinutes,
            EstimatedPomodoros = pomodoros,
            Priority = clampedPriority,
            EnergyLevel = normalizedEnergy,
            RecurrenceRule = normalizedRecurrence,
            DueDate = dueDate,
            ParentTaskId = parentTaskId,
            CreatedAt = DateTime.UtcNow,
            IsCompleted = false
        };

        _dbContext.TaskItems.Add(task);
        await _dbContext.SaveChangesAsync();
        return task;
    }

    public async Task<TaskItem?> UpdateTaskAsync(TaskItem task)
    {
        var existing = await _dbContext.TaskItems.FindAsync(task.Id);
        if (existing == null) return null;

        existing.Title = task.Title;
        existing.Description = task.Description;
        existing.EstimatedMinutes = task.EstimatedMinutes;
        existing.EstimatedPomodoros = task.EstimatedPomodoros;
        existing.CompletedPomodoros = task.CompletedPomodoros;
        existing.Priority = Math.Clamp(task.Priority, 0, 3);
        existing.EnergyLevel = NormalizeEnergy(task.EnergyLevel);
        existing.RecurrenceRule = NormalizeRecurrence(task.RecurrenceRule);
        existing.DueDate = task.DueDate;
        existing.IsCompleted = task.IsCompleted;

        await _dbContext.SaveChangesAsync();
        return existing;
    }

    public async Task ToggleTaskCompletionAsync(Guid taskId)
    {
        var task = await _dbContext.TaskItems.FindAsync(taskId);
        if (task != null)
        {
            task.IsCompleted = !task.IsCompleted;
            await _dbContext.SaveChangesAsync();
        }
    }

    public async Task DeleteTaskAsync(Guid taskId)
    {
        var task = await _dbContext.TaskItems.FindAsync(taskId);
        if (task != null)
        {
            _dbContext.TaskItems.Remove(task);
            await _dbContext.SaveChangesAsync();
        }
    }

    private static string NormalizeEnergy(string? energy)
    {
        if (string.IsNullOrWhiteSpace(energy))
            return string.Empty;

        var e = energy.Trim().ToLowerInvariant();
        return e is "deep" or "shallow" or "admin" ? e : string.Empty;
    }

    private static string? NormalizeRecurrence(string? rule)
    {
        if (string.IsNullOrWhiteSpace(rule) || rule.Equals("None", StringComparison.OrdinalIgnoreCase))
            return null;

        var r = rule.Trim().ToUpperInvariant();
        return r switch
        {
            "DAILY" or "FREQ=DAILY" => "FREQ=DAILY",
            "WEEKLY" or "FREQ=WEEKLY" => "FREQ=WEEKLY",
            _ => rule.Trim()
        };
    }
}
