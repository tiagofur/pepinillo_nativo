using System.ComponentModel;
using Microsoft.UI.Windowing;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Pepinillo.Core.Models;
using Pepinillo.Core.Utilities;
using Pepinillo.Core.ViewModels;

namespace Pepinillo.WinUI.Views;

/// <summary>
/// Compact Overlay (or small floating) mini timer synchronized with <see cref="FocusViewModel"/>.
/// Placement restore/save is owned by <c>MiniTimerController</c> (W14 multi-monitor).
/// </summary>
public sealed partial class MiniTimerWindow : Window
{
    private readonly FocusViewModel _viewModel;

    public MiniTimerWindow(FocusViewModel viewModel, bool alwaysOnTop = true)
    {
        _viewModel = viewModel;
        InitializeComponent();
        Title = "Pepinillo Mini";

        ConfigurePresenter(alwaysOnTop);
        SyncAll();

        _viewModel.PropertyChanged += OnViewModelPropertyChanged;
        Closed += OnClosed;
    }

    private void ConfigurePresenter(bool alwaysOnTop)
    {
        var appWindow = AppWindow;
        if (appWindow == null)
            return;

        if (alwaysOnTop && AppWindowTitleBar.IsCustomizationSupported())
        {
            // Compact Overlay is the productized always-on-top mini surface.
            if (appWindow.Presenter is not CompactOverlayPresenter)
                appWindow.SetPresenter(AppWindowPresenterKind.CompactOverlay);
        }
        else
        {
            appWindow.SetPresenter(AppWindowPresenterKind.Overlapped);
            if (appWindow.Presenter is OverlappedPresenter overlapped)
            {
                overlapped.IsAlwaysOnTop = alwaysOnTop;
                overlapped.IsResizable = false;
                overlapped.IsMaximizable = false;
                overlapped.IsMinimizable = false;
            }
        }

        // Default size; controller may override with persisted bounds.
        try
        {
            appWindow.Resize(new Windows.Graphics.SizeInt32(
                MiniTimerPlacement.DefaultWidth,
                MiniTimerPlacement.DefaultHeight));
        }
        catch
        {
            // Never crash on presenter/size setup.
        }
    }

    private void OnViewModelPropertyChanged(object? sender, PropertyChangedEventArgs e)
    {
        // PropertyChanged may arrive from timer thread — marshal to UI.
        DispatcherQueue.TryEnqueue(() =>
        {
            switch (e.PropertyName)
            {
                case nameof(FocusViewModel.FormattedTime):
                    TimerText.Text = _viewModel.FormattedTime;
                    break;
                case nameof(FocusViewModel.StatusLabel):
                case nameof(FocusViewModel.CurrentState):
                case nameof(FocusViewModel.CanPause):
                    StatusText.Text = _viewModel.StatusLabel;
                    UpdatePlayPauseGlyph();
                    break;
                case nameof(FocusViewModel.ActiveTaskTitle):
                    TaskText.Text = _viewModel.ActiveTaskTitle;
                    break;
                case null:
                    SyncAll();
                    break;
            }
        });
    }

    private void SyncAll()
    {
        TimerText.Text = _viewModel.FormattedTime;
        StatusText.Text = _viewModel.StatusLabel;
        TaskText.Text = _viewModel.ActiveTaskTitle;
        UpdatePlayPauseGlyph();
    }

    private void UpdatePlayPauseGlyph()
    {
        // Pause glyph when running/break; Play otherwise.
        var isRunning = _viewModel.CurrentState is SessionState.Running or SessionState.Break;
        PlayPauseIcon.Glyph = isRunning ? "\uE769" : "\uE768";
    }

    private void OnPlayPauseClick(object sender, RoutedEventArgs e)
    {
        _viewModel.TogglePlayPause();
        UpdatePlayPauseGlyph();
    }

    private void OnStopClick(object sender, RoutedEventArgs e)
    {
        _viewModel.StopSessionCommand.Execute(null);
        UpdatePlayPauseGlyph();
    }

    private void OnClosed(object sender, WindowEventArgs args)
    {
        _viewModel.PropertyChanged -= OnViewModelPropertyChanged;
        Closed -= OnClosed;
    }
}
