using System;
using System.Collections.ObjectModel;
using System.Globalization;
using System.Linq;
using System.Threading.Tasks;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using Pepinillo.Core.Models;
using Pepinillo.Core.Services;

namespace Pepinillo.Core.ViewModels;

/// <summary>
/// Desktop day planner (W13): hour grid + planned blocks, Start → Focus Time Blocking.
/// </summary>
public partial class CalendarViewModel : ObservableObject
{
    public const int DefaultGridStartHour = 6;
    public const int DefaultGridEndHour = 22;

    private readonly ITimeBlockPlanService _planService;
    private readonly ISettingsService _settingsService;
    private readonly ITaskService _taskService;
    private readonly IEntitlementService _entitlements;
    private readonly FocusViewModel _focusViewModel;
    private readonly ILocalizationService? _localizer;

    [ObservableProperty]
    private DateTime _selectedDay = DateTime.Today;

    [ObservableProperty]
    private string _dayLabel = string.Empty;

    [ObservableProperty]
    private ObservableCollection<CalendarHourSlot> _hourSlots = new();

    [ObservableProperty]
    private ObservableCollection<CalendarBlockRow> _plannedBlocks = new();

    [ObservableProperty]
    private ObservableCollection<TaskItem> _availableTasks = new();

    [ObservableProperty]
    private TaskItem? _selectedTask;

    [ObservableProperty]
    private bool _isLoading;

    [ObservableProperty]
    private bool _isEmpty = true;

    [ObservableProperty]
    private string _statusMessage = string.Empty;

    [ObservableProperty]
    private string _titleLabel = "Plan day";

    [ObservableProperty]
    private string _subtitleLabel =
        "Block deep-work hours on the desktop calendar. Start opens Focus in Time Blocking.";

    [ObservableProperty]
    private string _emptyHint = "No time blocks for this day. Add one from the hour list.";

    [ObservableProperty]
    private string _prevDayLabel = "Previous day";

    [ObservableProperty]
    private string _nextDayLabel = "Next day";

    [ObservableProperty]
    private string _todayLabel = "Today";

    [ObservableProperty]
    private string _blocksHeadingLabel = "Planned blocks";

    [ObservableProperty]
    private string _hoursHeadingLabel = "Hours";

    [ObservableProperty]
    private string _startLabel = "Start";

    [ObservableProperty]
    private string _deleteLabel = "Delete";

    [ObservableProperty]
    private string _linkTaskLabel = "Link task (optional)";

    [ObservableProperty]
    private string _premiumHint = string.Empty;

    /// <summary>Raised when free tier hits Time Blocking (create or start).</summary>
    public event EventHandler<string>? PremiumFeatureRequested;

    /// <summary>Raised after Focus is configured for a block — page should navigate to Focus.</summary>
    public event EventHandler? NavigateToFocusRequested;

    public CalendarViewModel(
        ITimeBlockPlanService planService,
        ISettingsService settingsService,
        ITaskService taskService,
        IEntitlementService entitlements,
        FocusViewModel focusViewModel,
        ILocalizationService? localizer = null)
    {
        _planService = planService;
        _settingsService = settingsService;
        _taskService = taskService;
        _entitlements = entitlements;
        _focusViewModel = focusViewModel;
        _localizer = localizer;
        BuildHourSlots();
        UpdateDayLabel();
    }

    [RelayCommand]
    public async Task LoadDayAsync()
    {
        IsLoading = true;
        try
        {
            await ApplyLanguageAsync();
            BuildHourSlots();
            UpdateDayLabel();

            try
            {
                var tasks = await _taskService.GetAllTasksAsync();
                AvailableTasks = new ObservableCollection<TaskItem>(
                    tasks.Where(t => !t.IsCompleted).ToList());
            }
            catch
            {
                AvailableTasks = new ObservableCollection<TaskItem>();
            }

            var (rangeStart, rangeEnd) = LocalDayUtcRange(SelectedDay);
            var blocks = await _planService.GetBetweenAsync(rangeStart, rangeEnd);
            var rows = blocks.Select(ToRow).ToList();
            PlannedBlocks = new ObservableCollection<CalendarBlockRow>(rows);
            IsEmpty = PlannedBlocks.Count == 0;
            if (IsEmpty)
                StatusMessage = string.Empty;
        }
        finally
        {
            IsLoading = false;
        }
    }

    [RelayCommand]
    public async Task PrevDayAsync()
    {
        SelectedDay = SelectedDay.Date.AddDays(-1);
        await LoadDayAsync();
    }

    [RelayCommand]
    public async Task NextDayAsync()
    {
        SelectedDay = SelectedDay.Date.AddDays(1);
        await LoadDayAsync();
    }

    [RelayCommand]
    public async Task GoTodayAsync()
    {
        SelectedDay = DateTime.Today;
        await LoadDayAsync();
    }

    /// <summary>
    /// Creates a block at the local hour on <see cref="SelectedDay"/>. Duration from settings.
    /// </summary>
    [RelayCommand]
    public async Task CreateAtHourAsync(int hourLocal)
    {
        if (hourLocal is < 0 or > 23)
            return;

        if (!_entitlements.CanUseFocusMode(FocusMode.TimeBlocking))
        {
            RaisePremiumGate();
            return;
        }

        var settings = await _settingsService.GetSettingsAsync();
        var duration = Math.Max(5, settings.TimeBlockingMinutes);
        var localStart = DateTime.SpecifyKind(SelectedDay.Date.AddHours(hourLocal), DateTimeKind.Local);
        var startUtc = localStart.ToUniversalTime();
        var title = T("Calendar.DefaultTitle", "Time Block");

        try
        {
            await _planService.CreateAsync(
                startUtc,
                duration,
                title,
                SelectedTask?.Id);
            StatusMessage = string.Empty;
            PremiumHint = string.Empty;
            await LoadDayAsync();
        }
        catch (InvalidOperationException ex)
        {
            HandlePremiumException(ex.Message);
        }
    }

    [RelayCommand]
    public async Task DeleteBlockAsync(CalendarBlockRow? row)
    {
        if (row == null)
            return;

        await _planService.DeleteAsync(row.Id);
        await LoadDayAsync();
    }

    /// <summary>
    /// Configures Focus for Time Blocking with the block duration/task and navigates to Focus.
    /// </summary>
    [RelayCommand]
    public void StartBlock(CalendarBlockRow? row)
    {
        if (row == null)
            return;

        if (!_entitlements.CanUseFocusMode(FocusMode.TimeBlocking))
        {
            RaisePremiumGate();
            return;
        }

        var ok = _focusViewModel.TryConfigureTimeBlock(
            row.DurationMinutes,
            row.TaskItemId,
            string.IsNullOrWhiteSpace(row.TaskTitle) ? null : row.TaskTitle);

        if (!ok)
        {
            // Focus may have raised its own paywall; mirror status for calendar.
            if (!_entitlements.CanUseFocusMode(FocusMode.TimeBlocking))
                RaisePremiumGate();
            else
                StatusMessage = T("Calendar.SessionBusy",
                    "Finish or stop the current focus session before starting a block.");
            return;
        }

        StatusMessage = string.Empty;
        PremiumHint = string.Empty;
        NavigateToFocusRequested?.Invoke(this, EventArgs.Empty);
    }

    private void RaisePremiumGate()
    {
        var msg = T("Calendar.PremiumRequired",
            "Time Blocking requires Pepinillo+ or Everywhere.");
        StatusMessage = msg;
        PremiumHint = msg;
        PremiumFeatureRequested?.Invoke(this, "time_blocking");
    }

    private void HandlePremiumException(string message)
    {
        StatusMessage = message.Contains("Time Blocking", StringComparison.OrdinalIgnoreCase)
            ? T("Calendar.PremiumRequired", "Time Blocking requires Pepinillo+ or Everywhere.")
            : message;
        PremiumHint = StatusMessage;
        PremiumFeatureRequested?.Invoke(this, "time_blocking");
    }

    private CalendarBlockRow ToRow(PlannedTimeBlock block)
    {
        var localStart = block.StartAtUtc.ToLocalTime();
        var localEnd = localStart.AddMinutes(block.DurationMinutes);
        var taskTitle = string.Empty;
        if (block.TaskItemId is Guid tid)
        {
            var match = AvailableTasks.FirstOrDefault(t => t.Id == tid);
            taskTitle = match?.Title ?? string.Empty;
        }

        return new CalendarBlockRow
        {
            Id = block.Id,
            StartAtUtc = block.StartAtUtc,
            DurationMinutes = block.DurationMinutes,
            Title = block.Title,
            TaskItemId = block.TaskItemId,
            IsCompleted = block.IsCompleted,
            TimeRangeLabel = $"{localStart:HH:mm} – {localEnd:HH:mm}",
            TaskTitle = taskTitle,
            DurationLabel = string.Format(
                CultureInfo.CurrentCulture,
                T("Calendar.DurationMinutes", "{0} min"),
                block.DurationMinutes)
        };
    }

    private void BuildHourSlots()
    {
        var addLabel = T("Calendar.AddAtHour", "Add");
        var slots = new ObservableCollection<CalendarHourSlot>();
        for (var h = DefaultGridStartHour; h <= DefaultGridEndHour; h++)
        {
            slots.Add(new CalendarHourSlot
            {
                HourLocal = h,
                HourLabel = $"{h:00}:00",
                AddButtonLabel = addLabel,
                AutomationName = string.Format(
                    CultureInfo.InvariantCulture,
                    "Add time block at {0:00}:00",
                    h)
            });
        }

        HourSlots = slots;
    }

    private void UpdateDayLabel()
    {
        DayLabel = SelectedDay.ToString("D", CultureInfo.CurrentCulture);
    }

    private async Task ApplyLanguageAsync()
    {
        if (_localizer == null)
        {
            UpdateDayLabel();
            return;
        }

        try
        {
            var settings = await _settingsService.GetSettingsAsync();
            _localizer.SetLanguage(settings.PreferredLanguage);
        }
        catch
        {
            // keep current language
        }

        TitleLabel = T("Calendar.Title", "Plan day");
        SubtitleLabel = T("Calendar.Subtitle",
            "Block deep-work hours on the desktop calendar. Start opens Focus in Time Blocking.");
        EmptyHint = T("Calendar.Empty", "No time blocks for this day. Add one from the hour list.");
        PrevDayLabel = T("Calendar.PrevDay", "Previous day");
        NextDayLabel = T("Calendar.NextDay", "Next day");
        TodayLabel = T("Calendar.Today", "Today");
        BlocksHeadingLabel = T("Calendar.BlocksHeading", "Planned blocks");
        HoursHeadingLabel = T("Calendar.HoursHeading", "Hours");
        StartLabel = T("Calendar.Start", "Start");
        DeleteLabel = T("Calendar.Delete", "Delete");
        LinkTaskLabel = T("Calendar.LinkTask", "Link task (optional)");
        UpdateDayLabel();
    }

    private string T(string key, string fallback) =>
        _localizer?.GetString(key) ?? fallback;

    /// <summary>
    /// Local calendar day → [utcStart, utcEnd) covering that local date.
    /// </summary>
    internal static (DateTime StartUtc, DateTime EndUtc) LocalDayUtcRange(DateTime localDay)
    {
        var localMidnight = DateTime.SpecifyKind(localDay.Date, DateTimeKind.Local);
        var start = localMidnight.ToUniversalTime();
        var end = localMidnight.AddDays(1).ToUniversalTime();
        return (start, end);
    }
}
