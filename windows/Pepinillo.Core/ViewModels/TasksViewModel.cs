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
    private DateTimeOffset? _newTaskDueDate = DateTimeOffset.Now;

    [ObservableProperty]
    private string _selectedFilter = "Today"; // Today, Upcoming, Inbox, All

    [ObservableProperty]
    private bool _isLoading;

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

        DateTime? dueDate = NewTaskDueDate?.DateTime;
        var createdTask = await _taskService.CreateTaskAsync(
            title: NewTaskTitle,
            estimatedMinutes: NewTaskEstimateMinutes,
            dueDate: dueDate
        );

        NewTaskTitle = string.Empty;
        await LoadTasksAsync();
    }

    [RelayCommand]
    public async Task ToggleTaskAsync(TaskItem task)
    {
        if (task == null) return;
        await _taskService.ToggleTaskCompletionAsync(task.Id);
        await LoadTasksAsync();
    }

    [RelayCommand]
    public async Task DeleteTaskAsync(TaskItem task)
    {
        if (task == null) return;
        await _taskService.DeleteTaskAsync(task.Id);
        await LoadTasksAsync();
    }

    [RelayCommand]
    public async Task FilterTasksAsync(string filter)
    {
        SelectedFilter = filter;
        await LoadTasksAsync();
    }
}
