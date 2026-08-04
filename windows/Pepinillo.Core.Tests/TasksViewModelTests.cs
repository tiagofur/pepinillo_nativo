using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Pepinillo.Core.Models;
using Pepinillo.Core.Services;
using Pepinillo.Core.ViewModels;
using Xunit;

namespace Pepinillo.Core.Tests;

public class TasksViewModelTests
{
    [Fact]
    public async Task CreateTask_ClearsTitle_ForRapidEntry()
    {
        var tasks = new RecordingTaskService();
        var vm = new TasksViewModel(tasks);
        vm.NewTaskTitle = "Ship W12";
        vm.NewTaskPriority = 2;
        vm.NewTaskEnergy = "deep";
        vm.NewTaskRecurrence = "FREQ=DAILY";

        var focusRequested = 0;
        vm.FocusNewTaskRequested += (_, _) => focusRequested++;

        await vm.CreateTaskCommand.ExecuteAsync(null);

        Assert.Equal(string.Empty, vm.NewTaskTitle);
        Assert.Equal(0, vm.NewTaskPriority);
        Assert.Equal(string.Empty, vm.NewTaskEnergy);
        Assert.Equal("None", vm.NewTaskRecurrence);
        Assert.Equal(1, focusRequested);
        Assert.Single(tasks.Created);
        Assert.Equal("Ship W12", tasks.Created[0].Title);
    }

    [Fact]
    public async Task FreeLimit_SetsStatusMessage_AndRaisesPremiumFeatureRequested()
    {
        var tasks = new RecordingTaskService
        {
            CreateException = new InvalidOperationException(
                $"Free plan allows at most {EntitlementService.FreeMaxIncompleteRootTasks} incomplete tasks. Upgrade to Pepinillo+ for unlimited tasks.")
        };
        var vm = new TasksViewModel(tasks);
        vm.NewTaskTitle = "Fourth task";

        string? requested = null;
        vm.PremiumFeatureRequested += (_, feature) => requested = feature;

        await vm.CreateTaskCommand.ExecuteAsync(null);

        Assert.Equal("tasks_limit", requested);
        Assert.Contains("3", vm.StatusMessage);
        Assert.Contains("Upgrade", vm.StatusMessage, StringComparison.OrdinalIgnoreCase);
        Assert.Equal("Fourth task", vm.NewTaskTitle); // not cleared on failure
    }

    [Fact]
    public async Task SubtasksPremium_RaisesPremiumFeatureRequested()
    {
        var tasks = new RecordingTaskService
        {
            CreateException = new InvalidOperationException("Subtasks require Pepinillo+ or Everywhere.")
        };
        var parent = new TaskItem { Title = "Parent" };
        var vm = new TasksViewModel(tasks)
        {
            NewSubtaskTitle = "Child"
        };

        string? requested = null;
        vm.PremiumFeatureRequested += (_, feature) => requested = feature;

        await vm.CreateSubtaskCommand.ExecuteAsync(parent);

        Assert.Equal("subtasks", requested);
        Assert.Contains("Subtasks", vm.StatusMessage);
    }

    [Fact]
    public async Task FilterTasks_UpdatesSelectedFilter_AndEmptyHint()
    {
        var tasks = new RecordingTaskService();
        var vm = new TasksViewModel(tasks);

        await vm.FilterTasksCommand.ExecuteAsync("Inbox");
        Assert.Equal("Inbox", vm.SelectedFilter);
        Assert.True(vm.IsEmpty);
        Assert.Contains("Inbox", vm.EmptyHint, StringComparison.OrdinalIgnoreCase);

        await vm.FilterTasksCommand.ExecuteAsync("Today");
        Assert.Equal("Today", vm.SelectedFilter);
        Assert.Contains("today", vm.EmptyHint, StringComparison.OrdinalIgnoreCase);

        await vm.FilterTasksCommand.ExecuteAsync("Upcoming");
        Assert.Equal("Upcoming", vm.SelectedFilter);
        Assert.Contains("upcoming", vm.EmptyHint, StringComparison.OrdinalIgnoreCase);

        await vm.FilterTasksCommand.ExecuteAsync("All");
        Assert.Equal("All", vm.SelectedFilter);
        Assert.False(string.IsNullOrWhiteSpace(vm.EmptyHint));
    }

    [Fact]
    public async Task LoadTasks_WhenItemsExist_IsNotEmpty()
    {
        var tasks = new RecordingTaskService();
        tasks.Today.Add(new TaskItem { Title = "Existing", DueDate = DateTime.UtcNow.Date });
        var vm = new TasksViewModel(tasks);

        await vm.LoadTasksCommand.ExecuteAsync(null);

        Assert.False(vm.IsEmpty);
        Assert.Single(vm.Tasks);
        Assert.Equal(string.Empty, vm.EmptyHint);
    }

    [Fact]
    public void FocusNewTaskComposer_RaisesFocusEvent()
    {
        var vm = new TasksViewModel(new RecordingTaskService());
        var raised = 0;
        vm.FocusNewTaskRequested += (_, _) => raised++;

        vm.FocusNewTaskComposerCommand.Execute(null);

        Assert.Equal(1, raised);
    }

    [Fact]
    public void TaskItem_EstimateChipLabel_FormatsMinutes()
    {
        var task = new TaskItem { EstimatedMinutes = 25, Priority = 2, EnergyLevel = "deep" };
        Assert.Equal("25m", task.EstimateChipLabel);
        Assert.True(task.HasEstimate);
        Assert.True(task.HasPriority);
        Assert.Equal("P2", task.PriorityLabel);
        Assert.Equal("Deep", task.EnergyLabel);
    }

    private sealed class RecordingTaskService : ITaskService
    {
        public List<TaskItem> Created { get; } = new();
        public List<TaskItem> Today { get; } = new();
        public List<TaskItem> Upcoming { get; } = new();
        public List<TaskItem> Inbox { get; } = new();
        public List<TaskItem> All { get; } = new();
        public Exception? CreateException { get; set; }

        public Task<List<TaskItem>> GetAllTasksAsync() => Task.FromResult(All.ToList());
        public Task<List<TaskItem>> GetTodayTasksAsync() => Task.FromResult(Today.ToList());
        public Task<List<TaskItem>> GetUpcomingTasksAsync() => Task.FromResult(Upcoming.ToList());
        public Task<List<TaskItem>> GetInboxTasksAsync() => Task.FromResult(Inbox.ToList());

        public Task<TaskItem> CreateTaskAsync(
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
            if (CreateException != null)
                throw CreateException;

            var item = new TaskItem
            {
                Title = title,
                EstimatedMinutes = estimatedMinutes,
                DueDate = dueDate,
                ParentTaskId = parentTaskId,
                Priority = priority,
                EnergyLevel = energyLevel,
                RecurrenceRule = recurrenceRule
            };
            Created.Add(item);
            if (parentTaskId == null)
            {
                Today.Add(item);
                All.Add(item);
            }

            return Task.FromResult(item);
        }

        public Task<TaskItem?> UpdateTaskAsync(TaskItem task) => Task.FromResult<TaskItem?>(task);
        public Task ToggleTaskCompletionAsync(Guid taskId) => Task.CompletedTask;
        public Task DeleteTaskAsync(Guid taskId) => Task.CompletedTask;
    }
}
