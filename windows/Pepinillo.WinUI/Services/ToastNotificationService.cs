using System;
using System.Threading.Tasks;
using Microsoft.Windows.AppNotifications;
using Microsoft.Windows.AppNotifications.Builder;
using Pepinillo.Core.Services;

namespace Pepinillo.WinUI.Services;

/// <summary>
/// Windows App SDK toast notifications. Gated by <c>EnableToastNotifications</c>.
/// </summary>
public sealed class ToastNotificationService : INotificationService
{
    private readonly ISettingsService _settingsService;
    private static bool _registered;
    private static readonly object RegisterLock = new();

    public ToastNotificationService(ISettingsService settingsService)
    {
        _settingsService = settingsService;
        EnsureRegistered();
    }

    public void ShowSessionCompletedToast(string sessionName, int durationMinutes)
    {
        ShowIfEnabled(
            "Focus session complete",
            $"{sessionName} · {durationMinutes} min of deep work. Nice work!");
    }

    public void ShowBreakStartedToast(bool isLongBreak)
    {
        var title = isLongBreak ? "Long break started" : "Break started";
        var body = isLongBreak
            ? "Take a longer reset — stretch, hydrate, look away from the screen."
            : "Short break — step away for a moment.";
        ShowIfEnabled(title, body);
    }

    public void ShowBreakCompletedToast()
    {
        ShowIfEnabled("Break finished", "Ready for deep work?");
    }

    public void ShowStreakMilestoneToast(int streakDays)
    {
        ShowIfEnabled("Streak milestone", $"{streakDays}-day focus streak. Keep the momentum!");
    }

    private void ShowIfEnabled(string title, string body)
    {
        _ = ShowAsync(title, body);
    }

    private async Task ShowAsync(string title, string body)
    {
        try
        {
            var settings = await _settingsService.GetSettingsAsync().ConfigureAwait(false);
            if (!settings.EnableToastNotifications)
                return;

            EnsureRegistered();

            var notification = new AppNotificationBuilder()
                .AddText(title)
                .AddText(body)
                .BuildNotification();

            AppNotificationManager.Default.Show(notification);
        }
        catch
        {
            // Best-effort: identity/permission failures must not crash the timer.
        }
    }

    private static void EnsureRegistered()
    {
        if (_registered)
            return;

        lock (RegisterLock)
        {
            if (_registered)
                return;

            try
            {
                AppNotificationManager.Default.Register();
                _registered = true;
            }
            catch
            {
                // Unpackaged without identity or already registered — keep trying per show.
            }
        }
    }
}
