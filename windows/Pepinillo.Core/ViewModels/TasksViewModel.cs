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
    private readonly ILocalizationService? _localizer;
    private readonly ISettingsService? _settings;

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

    /// <summary>Filter identity key: Today | Upcoming | Inbox | All (English, not localized).</summary>
    [ObservableProperty]
    private string _selectedFilter = "Today";

    [ObservableProperty]
    private bool _isLoading;

    [ObservableProperty]
    private bool _isEmpty = true;

    [ObservableProperty]
    private string _emptyHint = "No tasks here yet. Capture one above — even a 25-minute slice counts.";

    [ObservableProperty]
    private double _emptyPanelOpacity = 0.85;

    [ObservableProperty]
    private string _statusMessage = string.Empty;

    [ObservableProperty]
    private string _newSubtaskTitle = string.Empty;

    [ObservableProperty]
    private TaskItem? _subtaskParent;

    [ObservableProperty]
    private string _titleLabel = "Tasks";

    [ObservableProperty]
    private string _subtitleLabel =
        "Plan work into focus-sized tasks. Data is stored offline on this device.";

    [ObservableProperty]
    private string _filterTodayLabel = "Today";

    [ObservableProperty]
    private string _filterUpcomingLabel = "Upcoming";

    [ObservableProperty]
    private string _filterInboxLabel = "Inbox";

    [ObservableProperty]
    private string _filterAllLabel = "All";

    [ObservableProperty]
    private string _addTaskLabel = "Add task";

    [ObservableProperty]
    private string _addPlaceholder = "Add a new task…";

    [ObservableProperty]
    private string _titleFieldLabel = "Title";

    [ObservableProperty]
    private string _estimateLabel = "Est. (min)";

    [ObservableProperty]
    private string _priorityLabel = "Priority (0–3)";

    [ObservableProperty]
    private string _energyLabel = "Energy";

    [ObservableProperty]
    private string _recurrenceLabel = "Recurrence";

    [ObservableProperty]
    private string _addSubtaskLabel = "Add subtask";

    public string[] EnergyOptions { get; } = { "", "deep", "shallow", "admin" };
    public string[] RecurrenceOptions { get; } = { "None", "FREQ=DAILY", "FREQ=WEEKLY" };
    public int[] PriorityOptions { get; } = { 0, 1, 2, 3 };

    public TasksViewModel(
        ITaskService taskService,
        ILocalizationService? localizer = null,
        ISettingsService? settings = null)
    {
        _taskService = taskService;
        _localizer = localizer;
        _settings = settings;
    }

    partial void OnIsEmptyChanged(bool value)
    {
        EmptyHint = value ? ResolveEmptyHint() : string.Empty;
        EmptyPanelOpacity = value ? 0.85 : 0;
    }

    [RelayCommand]
    public async Task LoadTasksAsync()
    {
        IsLoading = true;
        try
        {
            await ApplyLanguageAsync();
            var taskList = SelectedFilter switch
            {
                "Today" => await _taskService.GetTodayTasksAsync(),
                "Upcoming" => await _taskService.GetUpcomingTasksAsync(),
                "Inbox" => await _taskService.GetInboxTasksAsync(),
                _ => await _taskService.GetAllTasksAsync()
            };

            Tasks = new ObservableCollection<TaskItem>(taskList);
            IsEmpty = Tasks.Count == 0;
            if (IsEmpty)
                EmptyHint = ResolveEmptyHint();
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

        try
        {
            await _taskService.CreateTaskAsync(
                title: NewTaskTitle,
                estimatedMinutes: NewTaskEstimateMinutes,
                dueDate: dueDate,
                priority: NewTaskPriority,
                energyLevel: NewTaskEnergy,
                recurrenceRule: NewTaskRecurrence);
        }
        catch (InvalidOperationException ex)
        {
            StatusMessage = LocalizeServiceException(ex.Message);
            return;
        }

        StatusMessage = string.Empty;
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

        try
        {
            await _taskService.CreateTaskAsync(
                title: NewSubtaskTitle,
                estimatedMinutes: 15,
                parentTaskId: parent.Id);
        }
        catch (InvalidOperationException ex)
        {
            StatusMessage = LocalizeServiceException(ex.Message);
            return;
        }

        StatusMessage = string.Empty;
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

    private async Task ApplyLanguageAsync()
    {
        if (_localizer == null) return;

        if (_settings != null)
        {
            try
            {
                var settings = await _settings.GetSettingsAsync();
                _localizer.SetLanguage(settings.PreferredLanguage);
            }
            catch
            {
                // keep current language
            }
        }

        TitleLabel = T("Tasks.Title", "Tasks");
        SubtitleLabel = T("Tasks.Subtitle",
            "Plan work into focus-sized tasks. Data is stored offline on this device.");
        FilterTodayLabel = T("Tasks.FilterToday", "Today");
        FilterUpcomingLabel = T("Tasks.FilterUpcoming", "Upcoming");
        FilterInboxLabel = T("Tasks.FilterInbox", "Inbox");
        FilterAllLabel = T("Tasks.FilterAll", "All");
        AddTaskLabel = T("Tasks.Add", "Add task");
        AddPlaceholder = T("Tasks.AddPlaceholder", "Add a new task…");
        TitleFieldLabel = T("Tasks.TitleField", "Title");
        EstimateLabel = T("Tasks.Estimate", "Est. (min)");
        PriorityLabel = T("Tasks.Priority", "Priority (0–3)");
        EnergyLabel = T("Tasks.Energy", "Energy");
        RecurrenceLabel = T("Tasks.Recurrence", "Recurrence");
        AddSubtaskLabel = T("Tasks.AddSubtask", "Add subtask");
        if (IsEmpty)
            EmptyHint = ResolveEmptyHint();
    }

    private string ResolveEmptyHint() => SelectedFilter switch
    {
        "Today" => T("Tasks.EmptyToday",
            "Nothing due today. Add a focus-sized task and start a Pomodoro."),
        "Upcoming" => T("Tasks.EmptyUpcoming",
            "No upcoming tasks. Plan tomorrow or switch to Inbox."),
        "Inbox" => T("Tasks.EmptyInbox",
            "Inbox is clear. Add a task when an idea lands."),
        _ => T("Tasks.EmptyDefault",
            "No tasks here yet. Capture one above — even a 25-minute slice counts.")
    };

    private string LocalizeServiceException(string message)
    {
        if (message.Contains("Subtasks require", StringComparison.OrdinalIgnoreCase))
            return T("Tasks.SubtasksPremium", "Subtasks require Pepinillo+ or Everywhere.");
        if (message.Contains("Recurring tasks require", StringComparison.OrdinalIgnoreCase))
            return T("Tasks.RecurrencePremium", "Recurring tasks require Pepinillo+ or Everywhere.");
        if (message.Contains("Free plan allows", StringComparison.OrdinalIgnoreCase))
            return string.Format(
                T("Tasks.FreeLimit",
                    "Free plan allows at most {0} incomplete tasks. Upgrade to Pepinillo+ for unlimited tasks."),
                EntitlementService.FreeMaxIncompleteRootTasks);
        return message;
    }

    private string T(string key, string fallback) =>
        _localizer?.GetString(key) ?? fallback;
}
