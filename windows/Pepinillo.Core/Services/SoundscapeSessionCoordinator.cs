using System;
using System.Linq;
using System.Threading.Tasks;
using Pepinillo.Core.Models;

namespace Pepinillo.Core.Services;

/// <summary>
/// Session-aware soundscape auto-play using settings + <see cref="IAudioPlayerService"/>.
/// On break: pause (with fade). On work resume: resume. On idle/complete: fade stop.
/// </summary>
public sealed class SoundscapeSessionCoordinator : ISoundscapeSessionCoordinator
{
    private readonly IAudioPlayerService _audio;
    private readonly ISettingsService _settings;
    private bool _startedByCoordinator;

    public SoundscapeSessionCoordinator(IAudioPlayerService audio, ISettingsService settings)
    {
        _audio = audio;
        _settings = settings;
    }

    public async Task OnSessionStateChangedAsync(SessionState previous, SessionState newState, bool isOnBreak)
    {
        try
        {
            // Terminal states always stop.
            if (newState is SessionState.Idle or SessionState.Completed)
            {
                if (_startedByCoordinator || _audio.IsPlaying || _audio.CurrentTrackId != null)
                {
                    await _audio.StopAsync(fade: true).ConfigureAwait(false);
                    _startedByCoordinator = false;
                }
                return;
            }

            // Break: pause for clarity (not duck volume).
            if (newState == SessionState.Break || isOnBreak && newState != SessionState.Running)
            {
                if (_audio.IsPlaying || _startedByCoordinator)
                    await _audio.PauseAsync(fade: true).ConfigureAwait(false);
                return;
            }

            // Active focus work.
            if (newState == SessionState.Running && !isOnBreak)
            {
                var settings = await _settings.GetSettingsAsync().ConfigureAwait(false);
                if (!settings.EnableSoundscapes || !settings.AutoPlaySoundscapeOnFocus)
                    return;

                // Resume after break (or pause that left a current track).
                if (previous == SessionState.Break
                    || (previous == SessionState.Paused && _audio.CurrentTrackId != null && !_audio.IsPlaying))
                {
                    if (_audio.CurrentTrackId != null)
                    {
                        await _audio.ResumeAsync(fade: true).ConfigureAwait(false);
                        _startedByCoordinator = true;
                        return;
                    }
                }

                // Already playing the preferred track — leave it.
                if (_audio.IsPlaying)
                {
                    _startedByCoordinator = true;
                    return;
                }

                var trackId = string.IsNullOrWhiteSpace(settings.PreferredSoundscapeId)
                    ? "rain"
                    : settings.PreferredSoundscapeId!;
                var volume = Math.Clamp(settings.SoundscapesMasterVolume, 0, 1);
                await _audio.PlayAsync(trackId, volume, loop: true).ConfigureAwait(false);
                _startedByCoordinator = true;
            }
        }
        catch
        {
            // Never crash the focus engine path.
        }
    }

    public async Task<string?> GetPreferredTrackDisplayNameAsync()
    {
        try
        {
            var settings = await _settings.GetSettingsAsync().ConfigureAwait(false);
            if (!settings.EnableSoundscapes)
                return null;

            var id = string.IsNullOrWhiteSpace(settings.PreferredSoundscapeId)
                ? "rain"
                : settings.PreferredSoundscapeId!;
            var track = _audio.GetAvailableSoundscapes().FirstOrDefault(t => t.Id == id);
            return track?.Name ?? id;
        }
        catch
        {
            return null;
        }
    }
}
