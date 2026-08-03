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
            .OrderByDescending(t => t.CreatedAt)
            .ToListAsync();
    }

    public async Task<List<TaskItem>> GetTodayTasksAsync()
    {
        var today = DateTime.UtcNow.Date;
        return await _dbContext.TaskItems
            .Include(t => t.SubTasks)
            .Where(t => t.DueDate.HasValue && t.DueDate.Value.Date <= today && !t.IsCompleted)
            .OrderBy(t => t.DueDate)
            .ToListAsync();
    }

    public async Task<List<TaskItem>> GetUpcomingTasksAsync()
    {
        var tomorrow = DateTime.UtcNow.Date.AddDays(1);
        return await _dbContext.TaskItems
            .Include(t => t.SubTasks)
            .Where(t => t.DueDate.HasValue && t.DueDate.Value.Date >= tomorrow && !t.IsCompleted)
            .OrderBy(t => t.DueDate)
            .ToListAsync();
    }

    public async Task<List<TaskItem>> GetInboxTasksAsync()
    {
        return await _dbContext.TaskItems
            .Include(t => t.SubTasks)
            .Where(t => !t.DueDate.HasValue && !t.IsCompleted && !t.ParentTaskId.HasValue)
            .OrderByDescending(t => t.CreatedAt)
            .ToListAsync();
    }

    public async Task<TaskItem> CreateTaskAsync(string title, string? description = null, int estimatedMinutes = 25, DateTime? dueDate = null, Guid? parentTaskId = null)
    {
        if (string.IsNullOrWhiteSpace(title))
            throw new ArgumentException("Title cannot be empty", nameof(title));

        var task = new TaskItem
        {
            Id = Guid.NewGuid(),
            Title = title.Trim(),
            Description = description,
            EstimatedMinutes = estimatedMinutes,
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
}
