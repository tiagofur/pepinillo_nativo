using System;
using System.IO;
using H.NotifyIcon;
using Microsoft.UI;
using Microsoft.UI.Dispatching;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Media;
using Pepinillo.Core.ViewModels;
using Windows.UI;

namespace Pepinillo.WinUI.Services;

/// <summary>
/// System tray icon with Start/Pause, Skip, Show window, Mini timer, Exit.
/// </summary>
public sealed class TrayIconService : ITrayIconService
{
    private readonly FocusViewModel _focusViewModel;
    private readonly IMiniTimerController _miniTimerController;
    private TaskbarIcon? _trayIcon;
    private Window? _mainWindow;
    private DispatcherQueue? _dispatcher;
    private bool _disposed;

    public bool IsExitRequested { get; private set; }

    public TrayIconService(FocusViewModel focusViewModel, IMiniTimerController miniTimerController)
    {
        _focusViewModel = focusViewModel;
        _miniTimerController = miniTimerController;
    }

    public void Initialize(Window mainWindow)
    {
        ObjectDisposedException.ThrowIf(_disposed, this);

        _mainWindow = mainWindow;
        _dispatcher = mainWindow.DispatcherQueue;

        if (_trayIcon != null)
            return;

        var flyout = new MenuFlyout();

        var playPause = new MenuFlyoutItem { Text = "Start / Pause" };
        playPause.Click += (_, _) => RunOnUi(() => _focusViewModel.TogglePlayPause());
        flyout.Items.Add(playPause);

        var skip = new MenuFlyoutItem { Text = "Skip break" };
        skip.Click += (_, _) => RunOnUi(() => _focusViewModel.SkipOrAdvance());
        flyout.Items.Add(skip);

        flyout.Items.Add(new MenuFlyoutSeparator());

        var showWindow = new MenuFlyoutItem { Text = "Show window" };
        showWindow.Click += (_, _) => RunOnUi(ShowMainWindow);
        flyout.Items.Add(showWindow);

        var miniTimer = new MenuFlyoutItem { Text = "Mini timer" };
        miniTimer.Click += (_, _) => RunOnUi(() => _miniTimerController.Toggle());
        flyout.Items.Add(miniTimer);

        flyout.Items.Add(new MenuFlyoutSeparator());

        var exit = new MenuFlyoutItem { Text = "Exit" };
        exit.Click += (_, _) => RunOnUi(RequestExit);
        flyout.Items.Add(exit);

        _trayIcon = new TaskbarIcon
        {
            ToolTipText = "Pepinillo — Deep Work OS",
            ContextFlyout = flyout,
            ContextMenuMode = ContextMenuMode.SecondWindow,
            MenuActivation = H.NotifyIcon.Core.PopupActivationMode.RightClick,
            NoLeftClickDelay = true,
            IconSource = CreateGeneratedIcon()
        };

        TryApplyFileIcon(_trayIcon);

        _trayIcon.LeftClickCommand = new RelayActionCommand(ShowMainWindow);
        _trayIcon.ForceCreate(enablesEfficiencyMode: true);

        _focusViewModel.PropertyChanged += OnFocusPropertyChanged;
        UpdateTooltip();
    }

    public void RequestExit()
    {
        IsExitRequested = true;

        try
        {
            _trayIcon?.Dispose();
            _trayIcon = null;
        }
        catch
        {
            // Ignore tray dispose races.
        }

        if (_mainWindow != null)
        {
            try
            {
                _mainWindow.Close();
            }
            catch
            {
                Application.Current?.Exit();
            }
        }
        else
        {
            Application.Current?.Exit();
        }
    }

    private void ShowMainWindow()
    {
        if (_mainWindow == null)
            return;

        try
        {
            // H.NotifyIcon window extensions restore from tray efficiently.
            WindowExtensions.Show(_mainWindow, disableEfficiencyMode: true);
        }
        catch
        {
            try
            {
                _mainWindow.AppWindow?.Show();
                _mainWindow.Activate();
            }
            catch
            {
                _mainWindow.Activate();
            }
        }
    }

    private void OnFocusPropertyChanged(object? sender, System.ComponentModel.PropertyChangedEventArgs e)
    {
        if (e.PropertyName is nameof(FocusViewModel.FormattedTime)
            or nameof(FocusViewModel.StatusLabel)
            or nameof(FocusViewModel.ActiveTaskTitle)
            or nameof(FocusViewModel.CurrentState)
            or null)
        {
            RunOnUi(UpdateTooltip);
        }
    }

    private void UpdateTooltip()
    {
        if (_trayIcon == null)
            return;

        try
        {
            _trayIcon.ToolTipText = BuildTooltipText(
                _focusViewModel.StatusLabel,
                _focusViewModel.FormattedTime,
                _focusViewModel.ActiveTaskTitle);
        }
        catch
        {
            // Tooltip updates must never throw from property-change handlers.
        }
    }

    /// <summary>
    /// Builds a tray tooltip: status · mm:ss · task (truncated for OS limits).
    /// </summary>
    internal static string BuildTooltipText(string? status, string? formattedTime, string? taskTitle)
    {
        var statusPart = string.IsNullOrWhiteSpace(status) ? "Pepinillo" : status.Trim();
        var timePart = string.IsNullOrWhiteSpace(formattedTime) ? "--:--" : formattedTime.Trim();
        var taskPart = string.IsNullOrWhiteSpace(taskTitle) ? null : taskTitle.Trim();

        var text = taskPart == null
            ? $"{statusPart} · {timePart}"
            : $"{statusPart} · {timePart} · {taskPart}";

        // Windows tray tooltip practical limit is ~127 characters.
        const int maxLen = 120;
        if (text.Length <= maxLen)
            return text;

        return text[..(maxLen - 1)] + "…";
    }

    private static GeneratedIconSource CreateGeneratedIcon()
    {
        return new GeneratedIconSource
        {
            Text = "P",
            FontSize = 18,
            Background = new SolidColorBrush(Color.FromArgb(255, 45, 159, 111)),
            Foreground = new SolidColorBrush(Colors.White)
        };
    }

    private static void TryApplyFileIcon(TaskbarIcon trayIcon)
    {
        try
        {
            var path = Path.Combine(AppContext.BaseDirectory, "Assets", "TrayIcon.ico");
            if (!File.Exists(path))
                return;

            trayIcon.Icon = new System.Drawing.Icon(path);
        }
        catch
        {
            // GeneratedIconSource remains as fallback.
        }
    }

    private void RunOnUi(Action action)
    {
        var queue = _dispatcher ?? DispatcherQueue.GetForCurrentThread();
        if (queue == null || queue.HasThreadAccess)
        {
            action();
            return;
        }

        queue.TryEnqueue(() => action());
    }

    public void Dispose()
    {
        if (_disposed)
            return;

        _disposed = true;
        _focusViewModel.PropertyChanged -= OnFocusPropertyChanged;

        try
        {
            _trayIcon?.Dispose();
        }
        catch
        {
            // Ignore.
        }

        _trayIcon = null;
        _mainWindow = null;
    }

    /// <summary>Minimal ICommand for tray left-click without extra packages.</summary>
    private sealed class RelayActionCommand : System.Windows.Input.ICommand
    {
        private readonly Action _action;

        public RelayActionCommand(Action action) => _action = action;

        public event EventHandler? CanExecuteChanged
        {
            add { }
            remove { }
        }

        public bool CanExecute(object? parameter) => true;

        public void Execute(object? parameter) => _action();
    }
}
