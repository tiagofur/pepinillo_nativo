using System;
using System.Collections.ObjectModel;
using System.Threading.Tasks;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using Pepinillo.Core.Models;
using Pepinillo.Core.Services;

namespace Pepinillo.Core.ViewModels;

public partial class TasksViewModel : ObservableObject
{
    private readonly ITaskService _taskService;

    [ObservableProperty]
    private ObservableCollection<TaskItem> _tasks = new();

    [ObservableProperty]
    private string _newTaskTitle = string.Empty;

    [ObservableProperty]
    private int _newTaskEstimateMinutes = 25;

    [ObservableProperty]
    private int _newTaskPriority;

    [ObservableProperty]
    private string _newTaskEnergy = string.Empty;

    [ObservableProperty]
    private string _newTaskRecurrence = "None";

    [ObservableProperty]
    private DateTimeOffset? _newTaskDueDate;

    [ObservableProperty]
    private string _selectedFilter = "Today";

    [ObservableProperty]
    private bool _isLoading;

    [ObservableProperty]
    private bool _isEmpty = true;

    [ObservableProperty]
    private string _newSubtaskTitle = string.Empty;

    [ObservableProperty]
    private TaskItem? _subtaskParent;

    public string[] EnergyOptions { get; } = { "", "deep", "shallow", "admin" };
    public string[] RecurrenceOptions { get; } = { "None", "FREQ=DAILY", "FREQ=WEEKLY" };
    public int[] PriorityOptions { get; } = { 0, 1, 2, 3 };

    public TasksViewModel(ITaskService taskService)
    {
        _taskService = taskService;
    }

    [RelayCommand]
    public async Task LoadTasksAsync()
    {
        IsLoading = true;
        try
        {
            var taskList = SelectedFilter switch
            {
                "Today" => await _taskService.GetTodayTasksAsync(),
                "Upcoming" => await _taskService.GetUpcomingTasksAsync(),
                "Inbox" => await _taskService.GetInboxTasksAsync(),
                _ => await _taskService.GetAllTasksAsync()
            };

            Tasks = new ObservableCollection<TaskItem>(taskList);
            IsEmpty = Tasks.Count == 0;
        }
        finally
        {
            IsLoading = false;
        }
    }

    [RelayCommand]
    public async Task CreateTaskAsync()
    {
        if (string.IsNullOrWhiteSpace(NewTaskTitle))
            return;

        DateTime? dueDate = SelectedFilter switch
        {
            "Today" => DateTime.UtcNow.Date,
            "Upcoming" => NewTaskDueDate?.UtcDateTime.Date ?? DateTime.UtcNow.Date.AddDays(1),
            "Inbox" => null,
            _ => NewTaskDueDate?.UtcDateTime
        };

        await _taskService.CreateTaskAsync(
            title: NewTaskTitle,
            estimatedMinutes: NewTaskEstimateMinutes,
            dueDate: dueDate,
            priority: NewTaskPriority,
            energyLevel: NewTaskEnergy,
            recurrenceRule: NewTaskRecurrence);

        NewTaskTitle = string.Empty;
        NewTaskPriority = 0;
        NewTaskEnergy = string.Empty;
        NewTaskRecurrence = "None";
        await LoadTasksAsync();
    }

    [RelayCommand]
    public async Task ToggleTaskAsync(TaskItem? task)
    {
        if (task == null) return;
        await _taskService.ToggleTaskCompletionAsync(task.Id);
        await LoadTasksAsync();
    }

    [RelayCommand]
    public async Task DeleteTaskAsync(TaskItem? task)
    {
        if (task == null) return;
        await _taskService.DeleteTaskAsync(task.Id);
        await LoadTasksAsync();
    }

    [RelayCommand]
    public async Task FilterTasksAsync(string filter)
    {
        if (string.IsNullOrWhiteSpace(filter))
            return;

        SelectedFilter = filter;
        await LoadTasksAsync();
    }

    [RelayCommand]
    public async Task CreateSubtaskAsync(TaskItem? parent)
    {
        if (parent == null || string.IsNullOrWhiteSpace(NewSubtaskTitle))
            return;

        await _taskService.CreateTaskAsync(
            title: NewSubtaskTitle,
            estimatedMinutes: 15,
            parentTaskId: parent.Id);

        NewSubtaskTitle = string.Empty;
        SubtaskParent = null;
        await LoadTasksAsync();
    }

    [RelayCommand]
    public void BeginAddSubtask(TaskItem? parent)
    {
        SubtaskParent = parent;
        NewSubtaskTitle = string.Empty;
    }

    [RelayCommand]
    public async Task ToggleSubtaskAsync(TaskItem? subtask)
    {
        if (subtask == null) return;
        await _taskService.ToggleTaskCompletionAsync(subtask.Id);
        await LoadTasksAsync();
    }
}
