namespace Pepinillo.Core.Services;

public interface INotificationService
{
    void ShowSessionCompletedToast(string sessionName, int durationMinutes);
    void ShowBreakStartedToast(bool isLongBreak);
    void ShowBreakCompletedToast();
    void ShowStreakMilestoneToast(int streakDays);
}
