using System.Collections.Generic;
using System.Linq;
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

    public List<SoundscapeTrack> GetAvailableSoundscapes() => _tracks.ToList();

    public void PlayTrack(string trackId, double volume = 0.5)
    {
        var track = _tracks.FirstOrDefault(t => t.Id == trackId);
        if (track == null) return;

        foreach (var t in _tracks)
            t.IsPlaying = false;

        track.IsPlaying = true;
        track.Volume = volume;
        _statusMessage = null;
    }

    public void StopTrack(string trackId)
    {
        var track = _tracks.FirstOrDefault(t => t.Id == trackId);
        if (track != null)
            track.IsPlaying = false;
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
    }

    public void PlaySessionCompletionSound()
    {
        // No-op in Core
    }
}
