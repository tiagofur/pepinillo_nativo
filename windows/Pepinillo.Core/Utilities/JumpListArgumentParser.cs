using System;

namespace Pepinillo.Core.Utilities;

/// <summary>
/// Jump List / protocol actions for desktop shell entry points (W14).
/// </summary>
public enum JumpListAction
{
    None = 0,
    Pomodoro,
    Tasks,
    Pause,
    Mini
}

/// <summary>
/// Parses launch arguments such as <c>action=pomodoro</c> into <see cref="JumpListAction"/>.
/// Platform hosts (WinUI Jump List, protocol activation) pass the raw string.
/// </summary>
public static class JumpListArgumentParser
{
    public const string ActionPomodoro = "action=pomodoro";
    public const string ActionTasks = "action=tasks";
    public const string ActionPause = "action=pause";
    public const string ActionMini = "action=mini";

    /// <summary>
    /// Parses Jump List / launch arguments. Accepts <c>action=…</c>, bare tokens, and
    /// multi-token strings containing an action pair. Case-insensitive. Unknown → None.
    /// </summary>
    public static JumpListAction Parse(string? arguments)
    {
        if (string.IsNullOrWhiteSpace(arguments))
            return JumpListAction.None;

        var text = arguments.Trim();

        // Prefer explicit action=value pairs anywhere in the string.
        foreach (var token in text.Split(new[] { ' ', '\t', '&', ';' }, StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries))
        {
            var action = ParseToken(token);
            if (action != JumpListAction.None)
                return action;
        }

        return ParseToken(text);
    }

    private static JumpListAction ParseToken(string token)
    {
        if (string.IsNullOrWhiteSpace(token))
            return JumpListAction.None;

        // action=value
        if (token.StartsWith("action=", StringComparison.OrdinalIgnoreCase))
        {
            var value = token["action=".Length..].Trim();
            return MapValue(value);
        }

        return MapValue(token);
    }

    private static JumpListAction MapValue(string value)
    {
        if (string.Equals(value, "pomodoro", StringComparison.OrdinalIgnoreCase)
            || string.Equals(value, "start", StringComparison.OrdinalIgnoreCase)
            || string.Equals(value, "focus", StringComparison.OrdinalIgnoreCase))
            return JumpListAction.Pomodoro;

        if (string.Equals(value, "tasks", StringComparison.OrdinalIgnoreCase)
            || string.Equals(value, "task", StringComparison.OrdinalIgnoreCase))
            return JumpListAction.Tasks;

        if (string.Equals(value, "pause", StringComparison.OrdinalIgnoreCase)
            || string.Equals(value, "resume", StringComparison.OrdinalIgnoreCase)
            || string.Equals(value, "playpause", StringComparison.OrdinalIgnoreCase)
            || string.Equals(value, "play-pause", StringComparison.OrdinalIgnoreCase)
            || string.Equals(value, "toggle", StringComparison.OrdinalIgnoreCase))
            return JumpListAction.Pause;

        if (string.Equals(value, "mini", StringComparison.OrdinalIgnoreCase)
            || string.Equals(value, "minitimer", StringComparison.OrdinalIgnoreCase)
            || string.Equals(value, "mini-timer", StringComparison.OrdinalIgnoreCase))
            return JumpListAction.Mini;

        return JumpListAction.None;
    }
}
