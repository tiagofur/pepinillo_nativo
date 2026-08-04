using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Pepinillo.Core.Models;

namespace Pepinillo.Core.Services;

/// <summary>
/// Catalog + no-op playback for Core/tests. WinUI replaces with MediaPlayer implementation.
/// </summary>
public class AudioPlayerService : IAudioPlayerService
{
    private readonly List<SoundscapeTrack> _tracks;
    private double _masterVolume = 0.7;
    private string? _statusMessage;
    private bool _isPlaying;
    private string? _currentTrackId;
    private bool _isPaused;

    public AudioPlayerService()
    {
        _tracks = BuildCatalog();
    }

    public static List<SoundscapeTrack> BuildCatalog() => new()
    {
        new() { Id = "rain", Name = "Rain", Category = "Nature", AudioFileName = "rain.mp3", Volume = 0.6, IsPremium = false },
        new() { Id = "forest", Name = "Forest", Category = "Nature", AudioFileName = "forest.mp3", Volume = 0.5, IsPremium = false },
        new() { Id = "ocean", Name = "Ocean", Category = "Nature", AudioFileName = "ocean.mp3", Volume = 0.5, IsPremium = false },
        new() { Id = "cafe", Name = "Cafe", Category = "Urban", AudioFileName = "cafe.mp3", Volume = 0.4, IsPremium = false },
        new() { Id = "whitenoise", Name = "White Noise", Category = "Noise", AudioFileName = "whitenoise.mp3", Volume = 0.3, IsPremium = true },
        new() { Id = "fireplace", Name = "Fireplace", Category = "Ambient", AudioFileName = "fireplace.mp3", Volume = 0.5, IsPremium = true },
        new() { Id = "deepspace", Name = "Deep Space", Category = "Ambient", AudioFileName = "deepspace.mp3", Volume = 0.5, IsPremium = true }
    };

    public string? LastStatusMessage => _statusMessage;
    public bool IsPlaying => _isPlaying && !_isPaused;
    public string? CurrentTrackId => _currentTrackId;

    public List<SoundscapeTrack> GetAvailableSoundscapes() => _tracks.ToList();

    public void PlayTrack(string trackId, double volume = 0.5) =>
        PlayAsync(trackId, volume, loop: true).GetAwaiter().GetResult();

    public void StopTrack(string trackId)
    {
        var track = _tracks.FirstOrDefault(t => t.Id == trackId);
        if (track != null)
            track.IsPlaying = false;

        if (_currentTrackId == trackId)
        {
            _isPlaying = false;
            _isPaused = false;
            _currentTrackId = null;
        }
    }

    public void SetTrackVolume(string trackId, double volume)
    {
        var track = _tracks.FirstOrDefault(t => t.Id == trackId);
        if (track != null)
            track.Volume = volume;
    }

    public void SetMasterVolume(double volume) => _masterVolume = System.Math.Clamp(volume, 0, 1);

    public double GetMasterVolume() => _masterVolume;

    public void StopAll()
    {
        foreach (var track in _tracks)
            track.IsPlaying = false;
        _isPlaying = false;
        _isPaused = false;
        _currentTrackId = null;
    }

    public void PlaySessionCompletionSound()
    {
        // No-op in Core
    }

    public Task PlayAsync(string trackId, double volume, bool loop = true)
    {
        var track = _tracks.FirstOrDefault(t => t.Id == trackId);
        if (track == null)
            return Task.CompletedTask;

        foreach (var t in _tracks)
            t.IsPlaying = false;

        track.IsPlaying = true;
        track.Volume = volume;
        _currentTrackId = trackId;
        _isPlaying = true;
        _isPaused = false;
        _statusMessage = null;
        return Task.CompletedTask;
    }

    public Task StopAsync(bool fade = true)
    {
        StopAll();
        return Task.CompletedTask;
    }

    public Task PauseAsync(bool fade = true)
    {
        if (!_isPlaying || _currentTrackId == null)
            return Task.CompletedTask;

        _isPaused = true;
        var track = _tracks.FirstOrDefault(t => t.Id == _currentTrackId);
        if (track != null)
            track.IsPlaying = false;
        return Task.CompletedTask;
    }

    public Task ResumeAsync(bool fade = true)
    {
        if (_currentTrackId == null || !_isPaused)
            return Task.CompletedTask;

        _isPaused = false;
        _isPlaying = true;
        var track = _tracks.FirstOrDefault(t => t.Id == _currentTrackId);
        if (track != null)
            track.IsPlaying = true;
        return Task.CompletedTask;
    }

    public Task SetVolumeAsync(double volume)
    {
        _masterVolume = System.Math.Clamp(volume, 0, 1);
        return Task.CompletedTask;
    }
}
