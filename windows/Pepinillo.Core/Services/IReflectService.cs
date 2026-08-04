using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using Pepinillo.Core.Models;

namespace Pepinillo.Core.Services;

/// <summary>
/// Reflect pillar: FREE achievements + premium Weekly/Monthly review aggregates.
/// </summary>
public interface IReflectService
{
    /// <summary>
    /// Computes the six FREE achievements from local completed sessions.
    /// </summary>
    Task<IReadOnlyList<AchievementProgress>> GetAchievementsAsync(DateTime? utcNow = null);

    /// <summary>
    /// This UTC Monday–Sunday week vs previous week. Pass <paramref name="includeDetails"/> false for free teaser.
    /// </summary>
    Task<PeriodReviewSummary> GetWeeklyReviewAsync(DateTime? utcNow = null, bool includeDetails = true);

    /// <summary>
    /// This UTC calendar month vs previous month. Pass <paramref name="includeDetails"/> false for free teaser.
    /// </summary>
    Task<PeriodReviewSummary> GetMonthlyReviewAsync(DateTime? utcNow = null, bool includeDetails = true);
}
