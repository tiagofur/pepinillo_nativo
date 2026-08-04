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
        }
    }

    [RelayCommand]
    private void PlayTrack(SoundscapeTrack? track)
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
            _audio.PlayTrack(track.Id, track.Volume * MasterVolume);
            if (!string.IsNullOrEmpty(_audio.LastStatusMessage))
            {
                StatusMessage = _audio.LastStatusMessage;
            }
            else
            {
                StatusMessage = $"Playing {track.Name}";
            }

            RefreshPlayingFlags();
        }
        catch (Exception ex)
        {
            StatusMessage = $"Playback error: {ex.Message}";
        }
    }

    [RelayCommand]
    private void StopTrack(SoundscapeTrack? track)
    {
        if (track == null) return;
        _audio.StopTrack(track.Id);
        StatusMessage = "Stopped";
        RefreshPlayingFlags();
    }

    [RelayCommand]
    private void StopAll()
    {
        _audio.StopAll();
        StatusMessage = "All stopped";
        RefreshPlayingFlags();
    }

    partial void OnMasterVolumeChanged(double value)
    {
        _audio.SetMasterVolume(value);
        var playing = Tracks.FirstOrDefault(t => t.IsPlaying);
        if (playing != null)
            _audio.SetTrackVolume(playing.Id, playing.Volume * value);
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
