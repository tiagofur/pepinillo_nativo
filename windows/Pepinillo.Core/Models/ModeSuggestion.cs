namespace Pepinillo.Core.Models;

/// <summary>
/// Where a mode suggestion came from (priority: Task → Energy → Global).
/// </summary>
public enum ModeSuggestionSource
{
    Task,
    Energy,
    Global
}

/// <summary>
/// Local Mode Intelligence recommendation from historical FocusSession data.
/// </summary>
public sealed class ModeSuggestion
{
    public FocusMode SuggestedMode { get; init; }

    /// <summary>Score / confidence in 0.0–1.0 (task/global: weighted score; energy: completion rate).</summary>
    public double Confidence { get; init; }

    /// <summary>Human-readable explanation for the Focus banner.</summary>
    public string Reason { get; init; } = string.Empty;

    public ModeSuggestionSource Source { get; init; }

    /// <summary>
    /// True when the user is free-tier: show locked teaser, do not apply the mode.
    /// </summary>
    public bool IsLocked { get; init; }
}
