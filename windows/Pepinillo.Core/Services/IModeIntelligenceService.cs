using System;
using System.Collections.Generic;
using Pepinillo.Core.Models;

namespace Pepinillo.Core.Services;

/// <summary>
/// Suggests an optimal <see cref="FocusMode"/> from local session history (Pepinillo+).
/// </summary>
public interface IModeIntelligenceService
{
    /// <summary>
    /// Returns a mode suggestion when data is sufficient and confidence/margin thresholds pass.
    /// Free tier receives a locked suggestion (teaser) when data would otherwise qualify; paid receives apply-ready data.
    /// Returns null when history is insufficient or no clear winner.
    /// </summary>
    /// <param name="sessions">Local focus sessions (any range; service filters).</param>
    /// <param name="taskId">Optional linked task id for task-specific scoring.</param>
    /// <param name="taskEnergy">Optional energy level of the linked task (deep/shallow/admin).</param>
    /// <param name="utcNow">Clock for global 30-day and hour-of-day buckets (inject for tests).</param>
    /// <param name="isPremium">When false, qualifying suggestions are returned locked.</param>
    /// <param name="taskEnergyById">Optional map of task id → energy for energy-level aggregation.</param>
    ModeSuggestion? Suggest(
        IReadOnlyList<FocusSession> sessions,
        Guid? taskId,
        string? taskEnergy,
        DateTime utcNow,
        bool isPremium,
        IReadOnlyDictionary<Guid, string>? taskEnergyById = null);
}
