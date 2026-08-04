using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using Pepinillo.Core.Models;
using Pepinillo.Core.Services;
using Windows.Media.Core;
using Windows.Media.Playback;
using Windows.Storage;

namespace Pepinillo.WinUI.Services;

/// <summary>
/// WinUI soundscape player using MediaPlayer. Loops when asset exists; degrades gracefully when missing.
/// Fades volume over ~500ms for play/pause/stop.
/// </summary>
public sealed class WindowsMediaPlayerService : IAudioPlayerService, IDisposable
{
    private const int FadeDurationMs = 500;
    private const int FadeSteps = 10;

    private readonly List<SoundscapeTrack> _tracks;
    private readonly MediaPlayer _player;
    private readonly object _gate = new();
    private double _masterVolume = 0.7;
    private double _trackVolume = 1.0;
    private string? _statusMessage;
    private string? _playingTrackId;
    private bool _isPlaying;
    private bool _isPaused;
    private CancellationTokenSource? _fadeCts;

    public string? LastStatusMessage
    {
        get { lock (_gate) return _statusMessage; }
    }

    public bool IsPlaying
    {
        get { lock (_gate) return _isPlaying && !_isPaused; }
    }

    public string? CurrentTrackId
    {
        get { lock (_gate) return _playingTrackId; }
    }

    public WindowsMediaPlayerService()
    {
        _tracks = AudioPlayerService.BuildCatalog();
        _player = new MediaPlayer
        {
            IsLoopingEnabled = true,
            AutoPlay = false,
            Volume = 0
        };
    }

    public List<SoundscapeTrack> GetAvailableSoundscapes() => _tracks.ToList();

    public void PlayTrack(string trackId, double volume = 0.5) =>
        PlayAsync(trackId, volume, loop: true).GetAwaiter().GetResult();

    public void StopTrack(string trackId)
    {
        lock (_gate)
        {
            var track = _tracks.FirstOrDefault(t => t.Id == trackId);
            if (track != null)
                track.IsPlaying = false;

            if (_playingTrackId != trackId)
                return;
        }

        StopAsync(fade: false).GetAwaiter().GetResult();
    }

    public void SetTrackVolume(string trackId, double volume)
    {
        lock (_gate)
        {
            var track = _tracks.FirstOrDefault(t => t.Id == trackId);
            if (track != null)
                track.Volume = volume;

            if (_playingTrackId == trackId)
            {
                _trackVolume = Math.Clamp(volume, 0, 1);
                if (_isPlaying && !_isPaused)
                    _player.Volume = Math.Clamp(_trackVolume * _masterVolume, 0, 1);
            }
        }
    }

    public void SetMasterVolume(double volume)
    {
        lock (_gate)
        {
            _masterVolume = Math.Clamp(volume, 0, 1);
            if (_isPlaying && !_isPaused)
                _player.Volume = Math.Clamp(_trackVolume * _masterVolume, 0, 1);
        }
    }

    public double GetMasterVolume()
    {
        lock (_gate) return _masterVolume;
    }

    public void StopAll() => StopAsync(fade: false).GetAwaiter().GetResult();

    public void PlaySessionCompletionSound()
    {
        // Optional short chime — not required for W3.
    }

    public async Task PlayAsync(string trackId, double volume, bool loop = true)
    {
        var track = _tracks.FirstOrDefault(t => t.Id == trackId);
        if (track == null)
            return;

        CancelFade();

        foreach (var t in _tracks)
            t.IsPlaying = false;

        track.Volume = volume;
        var target = Math.Clamp(volume * _masterVolume, 0, 1);

        lock (_gate)
        {
            _trackVolume = Math.Clamp(volume, 0, 1);
            _playingTrackId = trackId;
            _isPaused = false;
            _statusMessage = null;
        }

        try
        {
            _player.IsLoopingEnabled = loop;
            if (!TrySetSource(track.AudioFileName))
            {
                lock (_gate)
                {
                    track.IsPlaying = false;
                    _isPlaying = false;
                    _playingTrackId = null;
                    _statusMessage = "Audio asset missing";
                }
                try { _player.Pause(); } catch { /* ignore */ }
                return;
            }

            _player.Volume = 0;
            _player.Play();
            track.IsPlaying = true;
            lock (_gate) _isPlaying = true;

            await FadeToAsync(target).ConfigureAwait(false);
        }
        catch (Exception)
        {
            lock (_gate)
            {
                track.IsPlaying = false;
                _isPlaying = false;
                _playingTrackId = null;
                _statusMessage = "Audio asset missing";
            }
            try { _player.Pause(); } catch { /* ignore */ }
        }
    }

    public async Task StopAsync(bool fade = true)
    {
        CancelFade();

        if (fade && IsPlayingOrPaused())
        {
            await FadeToAsync(0).ConfigureAwait(false);
        }

        lock (_gate)
        {
            foreach (var t in _tracks)
                t.IsPlaying = false;
            _isPlaying = false;
            _isPaused = false;
            _playingTrackId = null;
        }

        try
        {
            _player.Pause();
            _player.Source = null;
            _player.Volume = 0;
        }
        catch
        {
            // ignore
        }
    }

    public async Task PauseAsync(bool fade = true)
    {
        string? id;
        lock (_gate)
        {
            id = _playingTrackId;
            if (id == null || (!_isPlaying && _isPaused))
                return;
        }

        CancelFade();

        if (fade)
            await FadeToAsync(0).ConfigureAwait(false);

        try { _player.Pause(); } catch { /* ignore */ }

        lock (_gate)
        {
            _isPaused = true;
            _isPlaying = false;
            var track = _tracks.FirstOrDefault(t => t.Id == id);
            if (track != null)
                track.IsPlaying = false;
        }
    }

    public async Task ResumeAsync(bool fade = true)
    {
        string? id;
        double target;
        lock (_gate)
        {
            id = _playingTrackId;
            if (id == null)
                return;
            target = Math.Clamp(_trackVolume * _masterVolume, 0, 1);
        }

        CancelFade();

        try
        {
            _player.Volume = 0;
            _player.Play();
        }
        catch
        {
            return;
        }

        lock (_gate)
        {
            _isPaused = false;
            _isPlaying = true;
            var track = _tracks.FirstOrDefault(t => t.Id == id);
            if (track != null)
                track.IsPlaying = true;
        }

        if (fade)
            await FadeToAsync(target).ConfigureAwait(false);
        else
            _player.Volume = target;
    }

    public Task SetVolumeAsync(double volume)
    {
        SetMasterVolume(volume);
        return Task.CompletedTask;
    }

    public void Dispose()
    {
        CancelFade();
        try
        {
            _player.Dispose();
        }
        catch
        {
            // ignore
        }
    }

    private bool IsPlayingOrPaused()
    {
        lock (_gate) return _playingTrackId != null && (_isPlaying || _isPaused);
    }

    private bool TrySetSource(string audioFileName)
    {
        try
        {
            var uri = new Uri($"ms-appx:///Assets/Soundscapes/{audioFileName}");
            _player.Source = MediaSource.CreateFromUri(uri);
            return true;
        }
        catch
        {
            try
            {
                var file = StorageFile.GetFileFromApplicationUriAsync(
                    new Uri($"ms-appx:///Assets/Soundscapes/{audioFileName}")).AsTask().GetAwaiter().GetResult();
                _player.Source = MediaSource.CreateFromStorageFile(file);
                return true;
            }
            catch
            {
                return false;
            }
        }
    }

    private void CancelFade()
    {
        try
        {
            _fadeCts?.Cancel();
            _fadeCts?.Dispose();
        }
        catch
        {
            // ignore
        }
        _fadeCts = null;
    }

    private async Task FadeToAsync(double targetVolume)
    {
        targetVolume = Math.Clamp(targetVolume, 0, 1);
        var cts = new CancellationTokenSource();
        lock (_gate)
        {
            CancelFade();
            _fadeCts = cts;
        }

        var token = cts.Token;
        double start;
        try { start = _player.Volume; }
        catch { start = 0; }

        var stepMs = FadeDurationMs / FadeSteps;
        try
        {
            for (var i = 1; i <= FadeSteps; i++)
            {
                token.ThrowIfCancellationRequested();
                var t = (double)i / FadeSteps;
                var v = start + (targetVolume - start) * t;
                try { _player.Volume = Math.Clamp(v, 0, 1); } catch { /* ignore */ }
                await Task.Delay(stepMs, token).ConfigureAwait(false);
            }
        }
        catch (OperationCanceledException)
        {
            // superseded by another fade/command
        }
    }
}
