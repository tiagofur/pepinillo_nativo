using System;
using System.Collections.Generic;
using System.Linq;
using Pepinillo.Core.Models;
using Pepinillo.Core.Services;
using Windows.Media.Core;
using Windows.Media.Playback;
using Windows.Storage;

namespace Pepinillo.WinUI.Services;

/// <summary>
/// WinUI soundscape player using MediaPlayer. Loops when asset exists; degrades gracefully when missing.
/// </summary>
public sealed class WindowsMediaPlayerService : IAudioPlayerService, IDisposable
{
    private readonly List<SoundscapeTrack> _tracks;
    private readonly MediaPlayer _player;
    private double _masterVolume = 0.7;
    private string? _statusMessage;
    private string? _playingTrackId;

    public string? LastStatusMessage => _statusMessage;

    public WindowsMediaPlayerService()
    {
        _tracks = AudioPlayerService.BuildCatalog();
        _player = new MediaPlayer
        {
            IsLoopingEnabled = true,
            AutoPlay = true,
            Volume = _masterVolume
        };
    }

    public List<SoundscapeTrack> GetAvailableSoundscapes() => _tracks.ToList();

    public void PlayTrack(string trackId, double volume = 0.5)
    {
        var track = _tracks.FirstOrDefault(t => t.Id == trackId);
        if (track == null)
            return;

        foreach (var t in _tracks)
            t.IsPlaying = false;

        track.Volume = volume;
        _playingTrackId = trackId;

        try
        {
            var uri = new Uri($"ms-appx:///Assets/Soundscapes/{track.AudioFileName}");
            _player.Source = MediaSource.CreateFromUri(uri);
            _player.Volume = Math.Clamp(volume * _masterVolume, 0, 1);
            _player.Play();
            track.IsPlaying = true;
            _statusMessage = null;
        }
        catch (Exception)
        {
            // Try StorageFile path under packaged Assets as second chance.
            try
            {
                var file = StorageFile.GetFileFromApplicationUriAsync(
                    new Uri($"ms-appx:///Assets/Soundscapes/{track.AudioFileName}")).AsTask().GetAwaiter().GetResult();
                _player.Source = MediaSource.CreateFromStorageFile(file);
                _player.Volume = Math.Clamp(volume * _masterVolume, 0, 1);
                _player.Play();
                track.IsPlaying = true;
                _statusMessage = null;
            }
            catch
            {
                track.IsPlaying = false;
                _statusMessage = "Audio asset missing";
                try { _player.Pause(); } catch { /* ignore */ }
            }
        }
    }

    public void StopTrack(string trackId)
    {
        var track = _tracks.FirstOrDefault(t => t.Id == trackId);
        if (track != null)
            track.IsPlaying = false;

        if (_playingTrackId == trackId)
        {
            try { _player.Pause(); } catch { /* ignore */ }
            _playingTrackId = null;
        }
    }

    public void SetTrackVolume(string trackId, double volume)
    {
        var track = _tracks.FirstOrDefault(t => t.Id == trackId);
        if (track != null)
            track.Volume = volume;

        if (_playingTrackId == trackId)
            _player.Volume = Math.Clamp(volume * _masterVolume, 0, 1);
    }

    public void SetMasterVolume(double volume)
    {
        _masterVolume = Math.Clamp(volume, 0, 1);
        var playing = _tracks.FirstOrDefault(t => t.IsPlaying);
        if (playing != null)
            _player.Volume = Math.Clamp(playing.Volume * _masterVolume, 0, 1);
        else
            _player.Volume = _masterVolume;
    }

    public double GetMasterVolume() => _masterVolume;

    public void StopAll()
    {
        foreach (var track in _tracks)
            track.IsPlaying = false;
        _playingTrackId = null;
        try { _player.Pause(); } catch { /* ignore */ }
    }

    public void PlaySessionCompletionSound()
    {
        // Optional short chime — not required for P2.
    }

    public void Dispose()
    {
        try
        {
            _player.Dispose();
        }
        catch
        {
            // ignore
        }
    }
}
