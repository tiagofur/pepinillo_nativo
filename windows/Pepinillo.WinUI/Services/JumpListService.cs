using System;
using System.Threading.Tasks;
using Microsoft.UI.Dispatching;
using Microsoft.UI.Xaml;
using Pepinillo.Core.Models;
using Pepinillo.Core.Utilities;
using Pepinillo.Core.ViewModels;
using Windows.UI.StartScreen;

namespace Pepinillo.WinUI.Services;

/// <summary>
/// Registers taskbar Jump List items and applies launch/activation arguments (W14).
/// Jump List APIs may throw when unpackaged — failures are non-fatal.
/// Pending arguments are applied after the main shell finishes first navigation
/// (see <see cref="NotifyShellReady"/>) so cold-start does not race onboarding/Focus.
/// </summary>
public sealed class JumpListService
{
    private readonly FocusViewModel _focusViewModel;
    private readonly IMiniTimerController _miniTimerController;
    private Window? _mainWindow;
    private DispatcherQueue? _dispatcher;
    private string? _pendingArguments;
    private bool _shellReady;

    public JumpListService(FocusViewModel focusViewModel, IMiniTimerController miniTimerController)
    {
        _focusViewModel = focusViewModel;
        _miniTimerController = miniTimerController;
    }

    public void Attach(Window mainWindow)
    {
        _mainWindow = mainWindow;
        _dispatcher = mainWindow.DispatcherQueue;
    }

    /// <summary>
    /// Loads and replaces the current Jump List. No-op on failure (unpackaged / OS limits).
    /// </summary>
    public static async Task TryRegisterAsync()
    {
        try
        {
            var jumpList = await JumpList.LoadCurrentAsync();
            jumpList.SystemGroupKind = JumpListSystemGroupKind.None;
            jumpList.Items.Clear();

            jumpList.Items.Add(CreateItem(
                displayName: "Start Pomodoro",
                description: "Open Focus and start a Pomodoro session",
                arguments: JumpListArgumentParser.ActionPomodoro,
                logo: "ms-appx:///Assets/Square44x44Logo.png"));

            jumpList.Items.Add(CreateItem(
                displayName: "Open Tasks",
                description: "Jump to the Tasks list",
                arguments: JumpListArgumentParser.ActionTasks,
                logo: "ms-appx:///Assets/Square44x44Logo.png"));

            jumpList.Items.Add(CreateItem(
                displayName: "Pause / Resume",
                description: "Toggle play or pause on the active timer",
                arguments: JumpListArgumentParser.ActionPause,
                logo: "ms-appx:///Assets/Square44x44Logo.png"));

            jumpList.Items.Add(CreateItem(
                displayName: "Mini timer",
                description: "Show or hide the compact mini timer",
                arguments: JumpListArgumentParser.ActionMini,
                logo: "ms-appx:///Assets/Square44x44Logo.png"));

            await jumpList.SaveAsync();
        }
        catch (Exception ex)
        {
            System.Diagnostics.Debug.WriteLine($"Jump List registration skipped: {ex.Message}");
        }
    }

    /// <summary>
    /// Queues launch arguments until the shell is ready, then applies them.
    /// </summary>
    public void HandleArguments(string? arguments)
    {
        if (string.IsNullOrWhiteSpace(arguments))
            return;

        if (JumpListArgumentParser.Parse(arguments) == JumpListAction.None)
            return;

        if (!_shellReady)
        {
            _pendingArguments = arguments;
            return;
        }

        RunOnUi(() => ApplyAction(JumpListArgumentParser.Parse(arguments)));
    }

    /// <summary>
    /// Called after MainWindow completes first navigation (onboarding gate).
    /// Flushes any pending Jump List cold-start action.
    /// </summary>
    public void NotifyShellReady()
    {
        _shellReady = true;
        var pending = _pendingArguments;
        _pendingArguments = null;
        if (string.IsNullOrWhiteSpace(pending))
            return;

        RunOnUi(() => ApplyAction(JumpListArgumentParser.Parse(pending)));
    }

    public void HandleAction(JumpListAction action)
    {
        if (action == JumpListAction.None)
            return;

        RunOnUi(() => ApplyAction(action));
    }

    private void ApplyAction(JumpListAction action)
    {
        try
        {
            switch (action)
            {
                case JumpListAction.Pomodoro:
                    ShowMainWindow();
                    NavigateMain("Focus");
                    try
                    {
                        _focusViewModel.SelectModeCommand.Execute(FocusMode.Pomodoro);
                    }
                    catch (Exception ex)
                    {
                        System.Diagnostics.Debug.WriteLine($"Jump List Pomodoro configure: {ex.Message}");
                    }

                    // Start only when idle/completed so we do not stomp a running session.
                    if (_focusViewModel.CurrentState is SessionState.Idle or SessionState.Completed)
                    {
                        try
                        {
                            _focusViewModel.TogglePlayPause();
                        }
                        catch (Exception ex)
                        {
                            System.Diagnostics.Debug.WriteLine($"Jump List Pomodoro start: {ex.Message}");
                        }
                    }

                    break;

                case JumpListAction.Tasks:
                    ShowMainWindow();
                    NavigateMain("Tasks");
                    break;

                case JumpListAction.Pause:
                    try
                    {
                        _focusViewModel.TogglePlayPause();
                    }
                    catch (Exception ex)
                    {
                        System.Diagnostics.Debug.WriteLine($"Jump List pause: {ex.Message}");
                    }

                    break;

                case JumpListAction.Mini:
                    try
                    {
                        _miniTimerController.Toggle();
                    }
                    catch (Exception ex)
                    {
                        System.Diagnostics.Debug.WriteLine($"Jump List mini: {ex.Message}");
                    }

                    break;
            }
        }
        catch (Exception ex)
        {
            System.Diagnostics.Debug.WriteLine($"Jump List action failed: {ex.Message}");
        }
    }

    private void ShowMainWindow()
    {
        if (_mainWindow == null)
            return;

        try
        {
            H.NotifyIcon.WindowExtensions.Show(_mainWindow, disableEfficiencyMode: true);
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
                try
                {
                    _mainWindow.Activate();
                }
                catch
                {
                    // ignore
                }
            }
        }
    }

    private void NavigateMain(string tag)
    {
        if (_mainWindow is MainWindow main)
            main.NavigateToTag(tag);
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

    private static JumpListItem CreateItem(string displayName, string description, string arguments, string logo)
    {
        var item = JumpListItem.CreateWithArguments(arguments, displayName);
        item.Description = description;
        try
        {
            item.Logo = new Uri(logo);
        }
        catch
        {
            // Logo is optional.
        }

        return item;
    }
}
