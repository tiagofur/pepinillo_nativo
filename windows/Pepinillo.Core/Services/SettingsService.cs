using System.Threading.Tasks;
using Microsoft.EntityFrameworkCore;
using Pepinillo.Core.Data;
using Pepinillo.Core.Models;

namespace Pepinillo.Core.Services;

public class SettingsService : ISettingsService
{
    private readonly PepinilloDbContext _dbContext;
    private UserSettings? _cache;

    public SettingsService(PepinilloDbContext dbContext)
    {
        _dbContext = dbContext;
    }

    public async Task<UserSettings> GetSettingsAsync()
    {
        if (_cache != null)
            return _cache;

        var settings = await _dbContext.UserSettings.FirstOrDefaultAsync(s => s.Id == 1);
        if (settings == null)
        {
            settings = new UserSettings { Id = 1 };
            _dbContext.UserSettings.Add(settings);
            await _dbContext.SaveChangesAsync();
        }

        _cache = settings;
        return settings;
    }

    public async Task SaveSettingsAsync(UserSettings settings)
    {
        settings.Id = 1;

        var existing = await _dbContext.UserSettings.FirstOrDefaultAsync(s => s.Id == 1);
        if (existing == null)
        {
            _dbContext.UserSettings.Add(settings);
            _cache = settings;
        }
        else if (!ReferenceEquals(existing, settings))
        {
            existing.PomodoroFocusMinutes = settings.PomodoroFocusMinutes;
            existing.ShortBreakMinutes = settings.ShortBreakMinutes;
            existing.LongBreakMinutes = settings.LongBreakMinutes;
            existing.LongBreakInterval = settings.LongBreakInterval;
            existing.FlowtimeTargetMinutes = settings.FlowtimeTargetMinutes;
            existing.TimeBlockingMinutes = settings.TimeBlockingMinutes;
            existing.AutoStartBreaks = settings.AutoStartBreaks;
            existing.AutoStartFocusSessions = settings.AutoStartFocusSessions;
            existing.EnableWindowsDoNotDisturbSync = settings.EnableWindowsDoNotDisturbSync;
            existing.MinimizeToSystemTrayOnClose = settings.MinimizeToSystemTrayOnClose;
            existing.LaunchAtWindowsStartup = settings.LaunchAtWindowsStartup;
            existing.EnableToastNotifications = settings.EnableToastNotifications;
            existing.EnableTickingSound = settings.EnableTickingSound;
            existing.TickingVolume = settings.TickingVolume;
            existing.EnableSoundscapes = settings.EnableSoundscapes;
            existing.SoundscapesMasterVolume = settings.SoundscapesMasterVolume;
            existing.AutoPlaySoundscapeOnFocus = settings.AutoPlaySoundscapeOnFocus;
            existing.PreferredSoundscapeId = settings.PreferredSoundscapeId;
            existing.SelectedTheme = settings.SelectedTheme;
            existing.UseMicaBackdrop = settings.UseMicaBackdrop;
            existing.CompactMiniTimerAlwaysOnTop = settings.CompactMiniTimerAlwaysOnTop;
            existing.PlayPauseHotkey = settings.PlayPauseHotkey;
            existing.SkipHotkey = settings.SkipHotkey;
            existing.MiniTimerHotkey = settings.MiniTimerHotkey;
            existing.PreferredLanguage = settings.PreferredLanguage;
            existing.DeviceId = settings.DeviceId;
            existing.LastSyncAtUtc = settings.LastSyncAtUtc;
            existing.StreakProtectionWeekStartUtc = settings.StreakProtectionWeekStartUtc;
            existing.StreakProtectionUsesThisWeek = settings.StreakProtectionUsesThisWeek;
            existing.HasCompletedOnboarding = settings.HasCompletedOnboarding;
            existing.PreferredFocusMode = settings.PreferredFocusMode;
            _cache = existing;
        }
        else
        {
            _cache = existing;
        }

        await _dbContext.SaveChangesAsync();
    }
}
