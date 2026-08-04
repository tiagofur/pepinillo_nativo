using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using Pepinillo.Core.Models;

namespace Pepinillo.Core.Services;

public interface ITaskService
{
    Task<List<TaskItem>> GetAllTasksAsync();
    Task<List<TaskItem>> GetTodayTasksAsync();
    Task<List<TaskItem>> GetUpcomingTasksAsync();
    Task<List<TaskItem>> GetInboxTasksAsync();
    Task<TaskItem> CreateTaskAsync(
        string title,
        string? description = null,
        int estimatedMinutes = 25,
        DateTime? dueDate = null,
        Guid? parentTaskId = null,
        int priority = 0,
        string energyLevel = "",
        string? recurrenceRule = null,
        int estimatedPomodoros = 0);
    Task<TaskItem?> UpdateTaskAsync(TaskItem task);
    Task ToggleTaskCompletionAsync(Guid taskId);
    Task DeleteTaskAsync(Guid taskId);
}
