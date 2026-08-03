using Microsoft.UI.Windowing;
using Microsoft.UI.Xaml;
using Pepinillo.Core.ViewModels;

namespace Pepinillo.WinUI.Views;

public sealed partial class MiniTimerWindow : Window
{
    private readonly FocusViewModel _viewModel;

    public MiniTimerWindow(FocusViewModel viewModel)
    {
        _viewModel = viewModel;
        this.InitializeComponent();

        // Enable Compact Overlay (Always-on-top mini window)
        var appWindow = this.AppWindow;
        if (appWindow != null)
        {
            appWindow.SetPresenter(AppWindowPresenterKind.CompactOverlay);
            appWindow.Resize(new Windows.Graphics.SizeInt32(280, 100));
        }

        _viewModel.PropertyChanged += (s, e) =>
        {
            if (e.PropertyName == nameof(FocusViewModel.FormattedTime))
            {
                TimerText.Text = _viewModel.FormattedTime;
            }
        };
    }

    private void OnPlayPauseClick(object sender, RoutedEventArgs e)
    {
        if (_viewModel.CurrentState == Pepinillo.Core.Models.SessionState.Running)
        {
            _viewModel.PauseSessionCommand.Execute(null);
            PlayPauseButton.Content = "▶";
        }
        else
        {
            _viewModel.StartSessionCommand.Execute(null);
            PlayPauseButton.Content = "⏸";
        }
    }

    private void OnStopClick(object sender, RoutedEventArgs e)
    {
        _viewModel.StopSessionCommand.Execute(null);
    }
}
