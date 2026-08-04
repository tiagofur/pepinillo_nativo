using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using Pepinillo.Core.Models;

namespace Pepinillo.Core.Services;

/// <summary>
/// Local day planner for desktop time blocks (W13). Premium for create (and start is gated by Focus).
/// </summary>
public interface ITimeBlockPlanService
{
    /// <summary>
    /// Returns blocks whose <see cref="PlannedTimeBlock.StartAtUtc"/> falls on the UTC calendar day of <paramref name="utcDay"/>.
    /// </summary>
    Task<IReadOnlyList<PlannedTimeBlock>> GetForDayAsync(DateTime utcDay);

    /// <summary>
    /// Returns blocks with <c>startUtcInclusive &lt;= StartAtUtc &lt; endUtcExclusive</c> (UTC).
    /// Preferred for local-day views that span a UTC midnight.
    /// </summary>
    Task<IReadOnlyList<PlannedTimeBlock>> GetBetweenAsync(DateTime startUtcInclusive, DateTime endUtcExclusive);

    /// <summary>
    /// Creates a planned block. Requires premium (Time Blocking is a paid focus mode).
    /// </summary>
    Task<PlannedTimeBlock> CreateAsync(
        DateTime startAtUtc,
        int durationMinutes,
        string? title = null,
        Guid? taskItemId = null);

    Task DeleteAsync(Guid id);
}
