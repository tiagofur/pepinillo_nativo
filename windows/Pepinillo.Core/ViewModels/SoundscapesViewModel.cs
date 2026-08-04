using System;
using System.Collections.ObjectModel;
using System.Linq;
using System.Threading.Tasks;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using Pepinillo.Core.Models;
using Pepinillo.Core.Services;

namespace Pepinillo.Core.ViewModels;

public partial class SoundscapesViewModel : ObservableObject
{
    private readonly IAudioPlayerService _audio;
    private readonly IStoreCommerceService _commerce;
    private readonly ISettingsService _settings;
    private readonly ILocalizationService? _localizer;

    public event EventHandler? PremiumGateRequested;

    [ObservableProperty]
    private ObservableCollection<SoundscapeTrack> _tracks = new();

    [ObservableProperty]
    private double _masterVolume = 0.7;

    [ObservableProperty]
    private string _statusMessage = string.Empty;

    [ObservableProperty]
    private string _titleLabel = "Soundscapes";

    [ObservableProperty]
    private string _volumeLabel = "Master volume";

    [ObservableProperty]
    private string _playLabel = "Play";

    [ObservableProperty]
    private string _stopLabel = "Stop";

    [ObservableProperty]
    private bool _hasPremium;

    public SoundscapesViewModel(
        IAudioPlayerService audio,
        IStoreCommerceService commerce,
        ISettingsService settings,
        ILocalizationService? localizer = null)
    {
        _audio = audio;
        _commerce = commerce;
        _settings = settings;
        _localizer = localizer;
    }

    public async Task LoadAsync()
    {
        var settings = await _settings.GetSettingsAsync();
        MasterVolume = settings.SoundscapesMasterVolume;
        _audio.SetMasterVolume(MasterVolume);

        try
        {
            await _commerce.CheckStoreEntitlementsAsync();
        }
        catch
        {
            // free default
        }

        HasPremium = _commerce.HasPremiumEntitlement();
        Tracks = new ObservableCollection<SoundscapeTrack>(_audio.GetAvailableSoundscapes());

        if (_localizer != null)
        {
            _localizer.SetLanguage(settings.PreferredLanguage);
            TitleLabel = _localizer.GetString("Soundscapes.Title");
            VolumeLabel = _localizer.GetString("Soundscapes.MasterVolume");
            PlayLabel = _localizer.GetString("Soundscapes.Play");
            StopLabel = _localizer.GetString("Soundscapes.Stop");
        }
    }

    [RelayCommand]
    private async Task PlayTrackAsync(SoundscapeTrack? track)
    {
        if (track == null) return;

        if (track.IsPremium && !HasPremium)
        {
            StatusMessage = _localizer?.GetString("Soundscapes.PremiumLocked")
                ?? "Premium — upgrade to unlock";
            PremiumGateRequested?.Invoke(this, EventArgs.Empty);
            return;
        }

        try
        {
            await _audio.PlayAsync(track.Id, MasterVolume, loop: true);
            if (!string.IsNullOrEmpty(_audio.LastStatusMessage))
            {
                StatusMessage = _audio.LastStatusMessage;
            }
            else
            {
                var template = _localizer?.GetString("Soundscapes.Playing") ?? "Playing {0}";
                StatusMessage = string.Format(template, track.Name);
            }

            // Last selected free/premium play becomes preferred for session auto-play.
            var settings = await _settings.GetSettingsAsync();
            settings.PreferredSoundscapeId = track.Id;
            settings.SoundscapesMasterVolume = MasterVolume;
            await _settings.SaveSettingsAsync(settings);

            RefreshPlayingFlags();
        }
        catch (Exception ex)
        {
            var template = _localizer?.GetString("Soundscapes.PlaybackError") ?? "Playback error: {0}";
            StatusMessage = string.Format(template, ex.Message);
        }
    }

    [RelayCommand]
    private async Task StopTrackAsync(SoundscapeTrack? track)
    {
        if (track == null) return;
        await _audio.StopAsync(fade: true);
        StatusMessage = _localizer?.GetString("Soundscapes.Stopped") ?? "Stopped";
        RefreshPlayingFlags();
    }

    [RelayCommand]
    private async Task StopAllAsync()
    {
        await _audio.StopAsync(fade: true);
        StatusMessage = _localizer?.GetString("Soundscapes.AllStopped") ?? "All stopped";
        RefreshPlayingFlags();
    }

    partial void OnMasterVolumeChanged(double value)
    {
        _audio.SetMasterVolume(value);
        _ = _audio.SetVolumeAsync(value);
    }

    public async Task PersistVolumeAsync()
    {
        var settings = await _settings.GetSettingsAsync();
        settings.SoundscapesMasterVolume = MasterVolume;
        await _settings.SaveSettingsAsync(settings);
    }

    private void RefreshPlayingFlags()
    {
        Tracks = new ObservableCollection<SoundscapeTrack>(_audio.GetAvailableSoundscapes());
    }
}
