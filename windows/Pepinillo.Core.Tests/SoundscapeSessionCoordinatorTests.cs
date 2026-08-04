using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Pepinillo.Core.Models;
using Pepinillo.Core.Services;
using Xunit;

namespace Pepinillo.Core.Tests;

public class SoundscapeSessionCoordinatorTests
{
    [Fact]
    public void Catalog_HasFourFreeAndThreePremium()
    {
        var tracks = AudioPlayerService.BuildCatalog();
        Assert.Equal(4, tracks.Count(t => !t.IsPremium));
        Assert.Equal(3, tracks.Count(t => t.IsPremium));
        Assert.Contains(tracks, t => t.Id == "rain" && t.AudioFileName == "rain.mp3");
        Assert.Contains(tracks, t => t.Id == "deepspace" && t.IsPremium);
    }

    [Fact]
    public async Task AutoPlay_RespectsEnableSoundscapesFalse()
    {
        var audio = new FakeAudioPlayer();
        var settings = new MutableSettingsService(new UserSettings
        {
            EnableSoundscapes = false,
            AutoPlaySoundscapeOnFocus = true,
            PreferredSoundscapeId = "rain",
            SoundscapesMasterVolume = 0.8
        });
        var coordinator = new SoundscapeSessionCoordinator(audio, settings);

        await coordinator.OnSessionStateChangedAsync(SessionState.Idle, SessionState.Running, isOnBreak: false);

        Assert.Empty(audio.PlayCalls);
        Assert.False(audio.IsPlaying);
    }

    [Fact]
    public async Task AutoPlay_RespectsAutoPlayFalse()
    {
        var audio = new FakeAudioPlayer();
        var settings = new MutableSettingsService(new UserSettings
        {
            EnableSoundscapes = true,
            AutoPlaySoundscapeOnFocus = false,
            PreferredSoundscapeId = "forest"
        });
        var coordinator = new SoundscapeSessionCoordinator(audio, settings);

        await coordinator.OnSessionStateChangedAsync(SessionState.Idle, SessionState.Running, isOnBreak: false);

        Assert.Empty(audio.PlayCalls);
    }

    [Fact]
    public async Task WorkStart_PlaysPreferredAtMasterVolume()
    {
        var audio = new FakeAudioPlayer();
        var settings = new MutableSettingsService(new UserSettings
        {
            EnableSoundscapes = true,
            AutoPlaySoundscapeOnFocus = true,
            PreferredSoundscapeId = "ocean",
            SoundscapesMasterVolume = 0.55
        });
        var coordinator = new SoundscapeSessionCoordinator(audio, settings);

        await coordinator.OnSessionStateChangedAsync(SessionState.Idle, SessionState.Running, isOnBreak: false);

        Assert.Single(audio.PlayCalls);
        Assert.Equal("ocean", audio.PlayCalls[0].TrackId);
        Assert.Equal(0.55, audio.PlayCalls[0].Volume);
        Assert.True(audio.IsPlaying);
    }

    [Fact]
    public async Task Break_PausesPlayback()
    {
        var audio = new FakeAudioPlayer();
        var settings = new MutableSettingsService(new UserSettings
        {
            EnableSoundscapes = true,
            AutoPlaySoundscapeOnFocus = true,
            PreferredSoundscapeId = "rain"
        });
        var coordinator = new SoundscapeSessionCoordinator(audio, settings);

        await coordinator.OnSessionStateChangedAsync(SessionState.Idle, SessionState.Running, isOnBreak: false);
        await coordinator.OnSessionStateChangedAsync(SessionState.Running, SessionState.Break, isOnBreak: true);

        Assert.Single(audio.PauseCalls);
        Assert.False(audio.IsPlaying);
        Assert.Equal("rain", audio.CurrentTrackId);
    }

    [Fact]
    public async Task BreakEnd_ResumesPlayback()
    {
        var audio = new FakeAudioPlayer();
        var settings = new MutableSettingsService(new UserSettings
        {
            EnableSoundscapes = true,
            AutoPlaySoundscapeOnFocus = true,
            PreferredSoundscapeId = "rain"
        });
        var coordinator = new SoundscapeSessionCoordinator(audio, settings);

        await coordinator.OnSessionStateChangedAsync(SessionState.Idle, SessionState.Running, isOnBreak: false);
        await coordinator.OnSessionStateChangedAsync(SessionState.Running, SessionState.Break, isOnBreak: true);
        await coordinator.OnSessionStateChangedAsync(SessionState.Break, SessionState.Running, isOnBreak: false);

        Assert.Single(audio.ResumeCalls);
        Assert.True(audio.IsPlaying);
    }

    [Fact]
    public async Task SessionComplete_StopsWithFade()
    {
        var audio = new FakeAudioPlayer();
        var settings = new MutableSettingsService(new UserSettings
        {
            EnableSoundscapes = true,
            AutoPlaySoundscapeOnFocus = true,
            PreferredSoundscapeId = "cafe"
        });
        var coordinator = new SoundscapeSessionCoordinator(audio, settings);

        await coordinator.OnSessionStateChangedAsync(SessionState.Idle, SessionState.Running, isOnBreak: false);
        await coordinator.OnSessionStateChangedAsync(SessionState.Running, SessionState.Completed, isOnBreak: false);

        Assert.Single(audio.StopCalls);
        Assert.True(audio.StopCalls[0]);
        Assert.False(audio.IsPlaying);
        Assert.Null(audio.CurrentTrackId);
    }

    [Fact]
    public async Task Idle_StopsPlayback()
    {
        var audio = new FakeAudioPlayer();
        var settings = new MutableSettingsService(new UserSettings
        {
            EnableSoundscapes = true,
            AutoPlaySoundscapeOnFocus = true,
            PreferredSoundscapeId = "rain"
        });
        var coordinator = new SoundscapeSessionCoordinator(audio, settings);

        await coordinator.OnSessionStateChangedAsync(SessionState.Idle, SessionState.Running, isOnBreak: false);
        await coordinator.OnSessionStateChangedAsync(SessionState.Running, SessionState.Idle, isOnBreak: false);

        Assert.Single(audio.StopCalls);
        Assert.False(audio.IsPlaying);
    }

    private sealed class MutableSettingsService : ISettingsService
    {
        private UserSettings _settings;

        public MutableSettingsService(UserSettings settings) => _settings = settings;

        public Task<UserSettings> GetSettingsAsync() => Task.FromResult(_settings);

        public Task SaveSettingsAsync(UserSettings settings)
        {
            _settings = settings;
            return Task.CompletedTask;
        }
    }

    private sealed class FakeAudioPlayer : IAudioPlayerService
    {
        public List<(string TrackId, double Volume, bool Loop)> PlayCalls { get; } = new();
        public List<bool> StopCalls { get; } = new();
        public List<bool> PauseCalls { get; } = new();
        public List<bool> ResumeCalls { get; } = new();

        private bool _isPlaying;
        private bool _isPaused;
        private string? _currentTrackId;
        private readonly List<SoundscapeTrack> _tracks = AudioPlayerService.BuildCatalog();

        public string? LastStatusMessage => null;
        public bool IsPlaying => _isPlaying && !_isPaused;
        public string? CurrentTrackId => _currentTrackId;

        public List<SoundscapeTrack> GetAvailableSoundscapes() => _tracks.ToList();

        public void PlayTrack(string trackId, double volume = 0.5) =>
            PlayAsync(trackId, volume).GetAwaiter().GetResult();

        public void StopTrack(string trackId) => StopAsync(false).GetAwaiter().GetResult();
        public void SetTrackVolume(string trackId, double volume) { }
        public void SetMasterVolume(double volume) { }
        public double GetMasterVolume() => 0.7;
        public void StopAll() => StopAsync(false).GetAwaiter().GetResult();
        public void PlaySessionCompletionSound() { }

        public Task PlayAsync(string trackId, double volume, bool loop = true)
        {
            PlayCalls.Add((trackId, volume, loop));
            _currentTrackId = trackId;
            _isPlaying = true;
            _isPaused = false;
            return Task.CompletedTask;
        }

        public Task StopAsync(bool fade = true)
        {
            StopCalls.Add(fade);
            _isPlaying = false;
            _isPaused = false;
            _currentTrackId = null;
            return Task.CompletedTask;
        }

        public Task PauseAsync(bool fade = true)
        {
            PauseCalls.Add(fade);
            _isPaused = true;
            _isPlaying = false;
            return Task.CompletedTask;
        }

        public Task ResumeAsync(bool fade = true)
        {
            ResumeCalls.Add(fade);
            if (_currentTrackId != null)
            {
                _isPaused = false;
                _isPlaying = true;
            }
            return Task.CompletedTask;
        }

        public Task SetVolumeAsync(double volume) => Task.CompletedTask;
    }
}
