using System;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Pepinillo.Core.Models;
using Pepinillo.Core.ViewModels;

namespace Pepinillo.WinUI.Views;

public sealed partial class SoundscapesPage : Page
{
    public SoundscapesViewModel ViewModel { get; }

    public SoundscapesPage()
    {
        ViewModel = App.Services.GetRequiredService<SoundscapesViewModel>();
        InitializeComponent();
        ViewModel.PremiumGateRequested += (_, _) =>
        {
            // Navigate to paywall via parent frame when available.
            Frame?.Navigate(typeof(PaywallPage));
        };
        Loaded += async (_, _) => await ViewModel.LoadAsync();
        Unloaded += async (_, _) =>
        {
            try { await ViewModel.PersistVolumeAsync(); }
            catch { /* ignore */ }
        };
    }

    private async void Play_Click(object sender, RoutedEventArgs e)
    {
        if (sender is FrameworkElement { Tag: SoundscapeTrack track })
            await ViewModel.PlayTrackCommand.ExecuteAsync(track);
    }

    private async void Stop_Click(object sender, RoutedEventArgs e)
    {
        if (sender is FrameworkElement { Tag: SoundscapeTrack track })
            await ViewModel.StopTrackCommand.ExecuteAsync(track);
    }

    private void Volume_ValueChanged(object sender, Microsoft.UI.Xaml.Controls.Primitives.RangeBaseValueChangedEventArgs e)
    {
        // TwoWay binding already updates MasterVolume; no-op handler for Slider ValueChanged requirement.
    }
}
