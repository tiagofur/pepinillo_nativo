using System.Collections.Generic;
using System.Linq;
using Pepinillo.Core.Models;

namespace Pepinillo.Core.Services;

public class AudioPlayerService : IAudioPlayerService
{
    private readonly List<SoundscapeTrack> _tracks;

    public AudioPlayerService()
    {
        _tracks = new List<SoundscapeTrack>
        {
            new() { Id = "rain", Name = "Lluvia Suave", Category = "Naturaleza", AudioFileName = "rain.mp3", Volume = 0.6, IsPremium = false },
            new() { Id = "forest", Name = "Bosque Encantado", Category = "Naturaleza", AudioFileName = "forest.mp3", Volume = 0.5, IsPremium = false },
            new() { Id = "ocean", Name = "Océano Profundo", Category = "Naturaleza", AudioFileName = "ocean.mp3", Volume = 0.5, IsPremium = false },
            new() { Id = "cafe", Name = "Cafetería París", Category = "Urbano", AudioFileName = "cafe.mp3", Volume = 0.4, IsPremium = false },
            new() { Id = "fireplace", Name = "Chimenea Acogedora", Category = "Ambiente", AudioFileName = "fireplace.mp3", Volume = 0.5, IsPremium = true },
            new() { Id = "whitenoise", Name = "Ruido Blanco", Category = "Ruido", AudioFileName = "whitenoise.mp3", Volume = 0.3, IsPremium = true },
            new() { Id = "deepspace", Name = "Espacio Profundo", Category = "Ambiente", AudioFileName = "deepspace.mp3", Volume = 0.5, IsPremium = true }
        };
    }

    public List<SoundscapeTrack> GetAvailableSoundscapes() => _tracks;

    public void PlayTrack(string trackId, double volume = 0.5)
    {
        var track = _tracks.FirstOrDefault(t => t.Id == trackId);
        if (track != null)
        {
            track.IsPlaying = true;
            track.Volume = volume;
        }
    }

    public void StopTrack(string trackId)
    {
        var track = _tracks.FirstOrDefault(t => t.Id == trackId);
        if (track != null)
        {
            track.IsPlaying = false;
        }
    }

    public void SetTrackVolume(string trackId, double volume)
    {
        var track = _tracks.FirstOrDefault(t => t.Id == trackId);
        if (track != null)
        {
            track.Volume = volume;
        }
    }

    public void StopAll()
    {
        foreach (var track in _tracks)
        {
            track.IsPlaying = false;
        }
    }

    public void PlaySessionCompletionSound()
    {
        // Chime audio output trigger
    }
}
