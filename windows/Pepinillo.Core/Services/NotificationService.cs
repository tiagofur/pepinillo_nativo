namespace Pepinillo.Core.Services;

/// <summary>
/// Default no-op notification service. WinUI host replaces with AppNotification implementation.
/// </summary>
public class NotificationService : INotificationService
{
    public void ShowSessionCompletedToast(string sessionName, int durationMinutes)
    {
        // Replaced by WinUI ToastNotificationService on desktop.
    }

    public void ShowBreakStartedToast(bool isLongBreak)
    {
        // Replaced by WinUI ToastNotificationService on desktop.
    }

    public void ShowBreakCompletedToast()
    {
        // Replaced by WinUI ToastNotificationService on desktop.
    }

    public void ShowStreakMilestoneToast(int streakDays)
    {
        // Replaced by WinUI ToastNotificationService on desktop.
    }
}
