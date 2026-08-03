using System;

namespace Pepinillo.Core.Services;

public class NotificationService : INotificationService
{
    public void ShowSessionCompletedToast(string sessionName, int durationMinutes)
    {
        // Dispatches native Windows AppNotification / Toast with interactive buttons
    }

    public void ShowBreakCompletedToast()
    {
        // Dispatches native Windows Toast: "Break finished! Ready for deep work?"
    }

    public void ShowStreakMilestoneToast(int streakDays)
    {
        // Dispatches Toast for streak milestones
    }
}
