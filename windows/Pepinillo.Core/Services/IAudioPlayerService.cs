using System.Collections.Generic;
using System.Threading.Tasks;
using Pepinillo.Core.Models;

namespace Pepinillo.Core.Services;

public interface IAudioPlayerService
{
    List<SoundscapeTrack> GetAvailableSoundscapes();

    /// <summary>Legacy sync play (no fade). Prefer <see cref="PlayAsync"/>.</summary>
    void PlayTrack(string trackId, double volume = 0.5);

    void StopTrack(string trackId);
    void SetTrackVolume(string trackId, double volume);
    void SetMasterVolume(double volume);
    double GetMasterVolume();
    void StopAll();
    void PlaySessionCompletionSound();
    string? LastStatusMessage { get; }

    /// <summary>Play track with optional loop; implementations may fade in.</summary>
    Task PlayAsync(string trackId, double volume, bool loop = true);

    /// <summary>Stop current playback; optionally fade out.</summary>
    Task StopAsync(bool fade = true);

    /// <summary>Pause current playback; optionally fade out then pause.</summary>
    Task PauseAsync(bool fade = true);

    /// <summary>Resume paused track; optionally fade in.</summary>
    Task ResumeAsync(bool fade = true);

    /// <summary>Set effective playback volume (0–1), typically master × track.</summary>
    Task SetVolumeAsync(double volume);

    bool IsPlaying { get; }
    string? CurrentTrackId { get; }
}
