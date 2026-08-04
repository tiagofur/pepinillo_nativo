using System;
using Pepinillo.Core.Models;

namespace Pepinillo.Core.Utilities;

/// <summary>
/// Maps Windows <see cref="FocusMode"/> to server wire strings and back.
/// Server: pomodoro, flowtime, timeblock, stopwatch (Android FocusModeSyncMapper parity).
/// </summary>
public static class FocusModeSyncMapper
{
    public static string ToServer(FocusMode mode) => mode switch
    {
        FocusMode.Pomodoro => "pomodoro",
        FocusMode.Flowtime => "flowtime",
        FocusMode.TimeBlocking => "timeblock",
        FocusMode.Stopwatch => "stopwatch",
        _ => "pomodoro"
    };

    /// <summary>String overload for aliases / tests (mirrors Android local mode names).</summary>
    public static string ToServer(string? localMode)
    {
        if (string.IsNullOrWhiteSpace(localMode))
            return "pomodoro";

        return localMode.Trim().ToLowerInvariant() switch
        {
            "pomodoro" => "pomodoro",
            "flow" or "flowtime" => "flowtime",
            "blocks" or "timeblock" or "time block" or "timeblocking" => "timeblock",
            "chrono" or "stopwatch" => "stopwatch",
            _ => Enum.TryParse<FocusMode>(localMode, ignoreCase: true, out var parsed)
                ? ToServer(parsed)
                : "pomodoro"
        };
    }

    public static FocusMode ToLocal(string? serverMode)
    {
        if (string.IsNullOrWhiteSpace(serverMode))
            return FocusMode.Pomodoro;

        return serverMode.Trim().ToLowerInvariant() switch
        {
            "pomodoro" => FocusMode.Pomodoro,
            "flow" or "flowtime" => FocusMode.Flowtime,
            "blocks" or "timeblock" or "time block" or "timeblocking" => FocusMode.TimeBlocking,
            "chrono" or "stopwatch" => FocusMode.Stopwatch,
            _ => FocusMode.Pomodoro
        };
    }
}
