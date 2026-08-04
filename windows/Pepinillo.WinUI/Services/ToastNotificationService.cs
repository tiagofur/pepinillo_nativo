using System;
using System.Threading.Tasks;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.UI.Dispatching;
using Microsoft.Windows.AppNotifications;
using Microsoft.Windows.AppNotifications.Builder;
using Pepinillo.Core.Services;
using Pepinillo.Core.ViewModels;

namespace Pepinillo.WinUI.Services;

/// <summary>
/// Windows App SDK toast notifications with Pause / Resume / Stop / Skip actions.
/// Gated by <c>EnableToastNotifications</c>.
/// Resolves <see cref="FocusViewModel"/> lazily to avoid a DI cycle with notifications.
/// </summary>
public sealed class ToastNotificationService : INotificationService
{
    private static readonly object RegisterLock = new();
    private static bool _registered;
    private static ToastNotificationService? s_instance;

    private readonly ISettingsService _settingsService;
    private readonly IServiceProvider _services;

    public ToastNotificationService(
        ISettingsService settingsService,
        IServiceProvider services)
    {
        _settingsService = settingsService;
        _services = services;
        s_instance = this;
        EnsureRegistered();
    }

    public void ShowSessionCompletedToast(string sessionName, int durationMinutes)
    {
        ShowIfEnabled(
            "Focus session complete",
            $"{sessionName} · {durationMinutes} min of deep work. Nice work!",
            ToastActionSet.ResumeStop);
    }

    public void ShowBreakStartedToast(bool isLongBreak)
    {
        var title = isLongBreak ? "Long break started" : "Break started";
        var body = isLongBreak
            ? "Take a longer reset — stretch, hydrate, look away from the screen."
            : "Short break — step away for a moment.";
        ShowIfEnabled(title, body, ToastActionSet.PauseSkipStop);
    }

    public void ShowBreakCompletedToast()
    {
        ShowIfEnabled(
            "Break finished",
            "Ready for deep work?",
            ToastActionSet.ResumeStop);
    }

    public void ShowStreakMilestoneToast(int streakDays)
    {
        ShowIfEnabled(
            "Streak milestone",
            $"{streakDays}-day focus streak. Keep the momentum!",
            ToastActionSet.None);
    }

    private void ShowIfEnabled(string title, string body, ToastActionSet actions)
    {
        _ = ShowAsync(title, body, actions);
    }

    private async Task ShowAsync(string title, string body, ToastActionSet actions)
    {
        try
        {
            var settings = await _settingsService.GetSettingsAsync().ConfigureAwait(false);
            if (!settings.EnableToastNotifications)
                return;

            EnsureRegistered();

            var builder = new AppNotificationBuilder()
                .AddText(title)
                .AddText(body);

            AddActionButtons(builder, actions);

            AppNotificationManager.Default.Show(builder.BuildNotification());
        }
        catch
        {
            // Best-effort: identity/permission failures must not crash the timer.
        }
    }

    private static void AddActionButtons(AppNotificationBuilder builder, ToastActionSet actions)
    {
        switch (actions)
        {
            case ToastActionSet.PauseSkipStop:
                builder.AddButton(new AppNotificationButton("Pause")
                    .AddArgument("action", "pause"));
                builder.AddButton(new AppNotificationButton("Skip")
                    .AddArgument("action", "skip"));
                builder.AddButton(new AppNotificationButton("Stop")
                    .AddArgument("action", "stop"));
                break;

            case ToastActionSet.ResumeStop:
                builder.AddButton(new AppNotificationButton("Resume")
                    .AddArgument("action", "resume"));
                builder.AddButton(new AppNotificationButton("Stop")
                    .AddArgument("action", "stop"));
                break;
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
                var manager = AppNotificationManager.Default;
                manager.NotificationInvoked -= OnNotificationInvokedStatic;
                manager.NotificationInvoked += OnNotificationInvokedStatic;
                manager.Register();
                _registered = true;
            }
            catch
            {
                // Unpackaged without identity or already registered — retry on next show.
            }
        }
    }

    private static void OnNotificationInvokedStatic(
        AppNotificationManager sender,
        AppNotificationActivatedEventArgs args)
    {
        s_instance?.OnNotificationInvoked(args);
    }

    private void OnNotificationInvoked(AppNotificationActivatedEventArgs args)
    {
        var action = ResolveAction(args);
        if (string.IsNullOrEmpty(action))
            return;

        MarshalToUi(() => DispatchAction(action));
    }

    private static string? ResolveAction(AppNotificationActivatedEventArgs args)
    {
        try
        {
            if (args.Arguments != null
                && args.Arguments.TryGetValue("action", out var value)
                && !string.IsNullOrWhiteSpace(value))
            {
                return value;
            }
        }
        catch
        {
            // ignore dictionary failures
        }

        try
        {
            var raw = args.Argument;
            if (string.IsNullOrWhiteSpace(raw))
                return null;

            foreach (var pair in raw.Split('&', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries))
            {
                var parts = pair.Split('=', 2);
                if (parts.Length == 2
                    && parts[0].Equals("action", StringComparison.OrdinalIgnoreCase))
                {
                    return Uri.UnescapeDataString(parts[1]);
                }
            }
        }
        catch
        {
            // ignore
        }

        return null;
    }

    private void DispatchAction(string action)
    {
        FocusViewModel focus;
        try
        {
            focus = _services.GetRequiredService<FocusViewModel>();
        }
        catch
        {
            return;
        }

        switch (action.ToLowerInvariant())
        {
            case "pause":
                if (focus.CanPause)
                    focus.PauseSessionCommand.Execute(null);
                break;
            case "resume":
                // Start when idle/paused/completed; ignore if already running.
                if (!focus.CanPause)
                    focus.TogglePlayPause();
                break;
            case "stop":
                focus.StopSessionCommand.Execute(null);
                break;
            case "skip":
                focus.SkipOrAdvance();
                break;
        }
    }

    private void MarshalToUi(Action action)
    {
        try
        {
            var queue = App.MainWindowInstance?.DispatcherQueue
                        ?? DispatcherQueue.GetForCurrentThread();
            if (queue == null || queue.HasThreadAccess)
            {
                action();
                return;
            }

            queue.TryEnqueue(() => action());
        }
        catch
        {
            try { action(); } catch { /* ignore */ }
        }
    }

    private enum ToastActionSet
    {
        None,
        PauseSkipStop,
        ResumeStop
    }
}
