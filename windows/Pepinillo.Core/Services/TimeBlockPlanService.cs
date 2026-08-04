using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Microsoft.EntityFrameworkCore;
using Pepinillo.Core.Data;
using Pepinillo.Core.Models;

namespace Pepinillo.Core.Services;

/// <summary>
/// SQLite-backed planned time blocks. Create is premium-gated (same product rule as Time Blocking focus mode).
/// </summary>
public class TimeBlockPlanService : ITimeBlockPlanService
{
    public const string PremiumRequiredMessage =
        "Time Blocking requires Pepinillo+ or Everywhere.";

    private readonly PepinilloDbContext _db;
    private readonly IEntitlementService _entitlements;

    public TimeBlockPlanService(PepinilloDbContext db, IEntitlementService entitlements)
    {
        _db = db;
        _entitlements = entitlements;
    }

    public Task<IReadOnlyList<PlannedTimeBlock>> GetForDayAsync(DateTime utcDay)
    {
        var dayStart = DateTime.SpecifyKind(utcDay.Date, DateTimeKind.Utc);
        return GetBetweenAsync(dayStart, dayStart.AddDays(1));
    }

    public async Task<IReadOnlyList<PlannedTimeBlock>> GetBetweenAsync(
        DateTime startUtcInclusive,
        DateTime endUtcExclusive)
    {
        var start = NormalizeUtc(startUtcInclusive);
        var end = NormalizeUtc(endUtcExclusive);

        return await _db.PlannedTimeBlocks
            .AsNoTracking()
            .Where(b => b.StartAtUtc >= start && b.StartAtUtc < end)
            .OrderBy(b => b.StartAtUtc)
            .ToListAsync();
    }

    public async Task<PlannedTimeBlock> CreateAsync(
        DateTime startAtUtc,
        int durationMinutes,
        string? title = null,
        Guid? taskItemId = null)
    {
        if (!_entitlements.CanUseFocusMode(FocusMode.TimeBlocking))
            throw new InvalidOperationException(PremiumRequiredMessage);

        var duration = Math.Clamp(durationMinutes, 5, 12 * 60);
        var start = NormalizeUtc(startAtUtc);

        var block = new PlannedTimeBlock
        {
            Id = Guid.NewGuid(),
            StartAtUtc = start,
            DurationMinutes = duration,
            Title = string.IsNullOrWhiteSpace(title) ? "Time Block" : title.Trim(),
            TaskItemId = taskItemId,
            IsCompleted = false,
            CreatedAtUtc = DateTime.UtcNow
        };

        _db.PlannedTimeBlocks.Add(block);
        await _db.SaveChangesAsync();
        return block;
    }

    public async Task DeleteAsync(Guid id)
    {
        var existing = await _db.PlannedTimeBlocks.FindAsync(id);
        if (existing == null)
            return;

        _db.PlannedTimeBlocks.Remove(existing);
        await _db.SaveChangesAsync();
    }

    private static DateTime NormalizeUtc(DateTime value) =>
        value.Kind switch
        {
            DateTimeKind.Utc => value,
            DateTimeKind.Local => value.ToUniversalTime(),
            _ => DateTime.SpecifyKind(value, DateTimeKind.Utc)
        };
}
