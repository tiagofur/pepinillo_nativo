namespace Pepinillo.Core.Services;

public interface INotificationService
{
    void ShowSessionCompletedToast(string sessionName, int durationMinutes);
    void ShowBreakCompletedToast();
    void ShowStreakMilestoneToast(int streakDays);
}
