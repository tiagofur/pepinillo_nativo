using System.Collections.Generic;
using Pepinillo.Core.Models;

namespace Pepinillo.Core.Services;

public interface IAudioPlayerService
{
    List<SoundscapeTrack> GetAvailableSoundscapes();
    void PlayTrack(string trackId, double volume = 0.5);
    void StopTrack(string trackId);
    void SetTrackVolume(string trackId, double volume);
    void StopAll();
    void PlaySessionCompletionSound();
}
