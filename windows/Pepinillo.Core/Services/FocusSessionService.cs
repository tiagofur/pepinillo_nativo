using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Microsoft.EntityFrameworkCore;
using Pepinillo.Core.Data;
using Pepinillo.Core.Models;

namespace Pepinillo.Core.Services;

public class FocusSessionService : IFocusSessionService
{
    private readonly PepinilloDbContext _dbContext;

    public FocusSessionService(PepinilloDbContext dbContext)
    {
        _dbContext = dbContext;
    }

    public async Task SaveSessionAsync(FocusSession session)
    {
        if (session.Id == Guid.Empty)
            session.Id = Guid.NewGuid();

        var existing = await _dbContext.FocusSessions.FindAsync(session.Id);
        if (existing == null)
        {
            _dbContext.FocusSessions.Add(session);
        }
        else
        {
            existing.Mode = session.Mode;
            existing.TargetDurationSeconds = session.TargetDurationSeconds;
            existing.ElapsedSeconds = session.ElapsedSeconds;
            existing.TaskItemId = session.TaskItemId;
            existing.StartedAt = session.StartedAt;
            existing.CompletedAt = session.CompletedAt;
            existing.IsCompleted = session.IsCompleted;
            existing.IsSynced = session.IsSynced;
            existing.JournalNote = session.JournalNote;
            existing.EnergyRating = session.EnergyRating;
        }

        await _dbContext.SaveChangesAsync();
    }

    public async Task UpdateJournalAsync(Guid sessionId, string? journalNote, int? energyRating)
    {
        var existing = await _dbContext.FocusSessions.FindAsync(sessionId);
        if (existing == null)
            return;

        existing.JournalNote = journalNote;
        if (energyRating is >= 1 and <= 5)
            existing.EnergyRating = energyRating;
        else if (energyRating is null)
            existing.EnergyRating = null;

        // Journal update may re-open sync delta.
        existing.IsSynced = false;
        await _dbContext.SaveChangesAsync();
    }

    public async Task<List<FocusSession>> GetRecentSessionsAsync(int count = 20)
    {
        return await _dbContext.FocusSessions
            .OrderByDescending(s => s.StartedAt)
            .Take(count)
            .ToListAsync();
    }

    public async Task<List<FocusSession>> GetSessionsInRangeAsync(DateTime utcStartInclusive, DateTime utcEndExclusive)
    {
        return await _dbContext.FocusSessions
            .Where(s => s.IsCompleted
                        && s.StartedAt >= utcStartInclusive
                        && s.StartedAt < utcEndExclusive)
            .OrderByDescending(s => s.StartedAt)
            .ToListAsync();
    }

    public async Task<int> GetTodayFocusMinutesAsync(DateTime? utcNow = null)
    {
        var now = utcNow ?? DateTime.UtcNow;
        var today = now.Date;
        var totalSeconds = await GetTotalFocusSecondsAsync(today, today.AddDays(1));
        return totalSeconds / 60;
    }

    public async Task<int> GetTotalFocusSecondsAsync(DateTime utcStartInclusive, DateTime utcEndExclusive)
    {
        return await _dbContext.FocusSessions
            .Where(s => s.IsCompleted
                        && s.StartedAt >= utcStartInclusive
                        && s.StartedAt < utcEndExclusive)
            .SumAsync(s => (int?)s.ElapsedSeconds) ?? 0;
    }

    public async Task<(int CurrentStreak, int BestStreak)> GetStreaksAsync(DateTime? utcToday = null)
    {
        var today = (utcToday ?? DateTime.UtcNow).Date;

        // Days with any completed focus > 0 seconds (UTC calendar days).
        var daySeconds = await _dbContext.FocusSessions
            .Where(s => s.IsCompleted && s.ElapsedSeconds > 0)
            .GroupBy(s => s.StartedAt.Date)
            .Select(g => new { Day = g.Key, Seconds = g.Sum(x => x.ElapsedSeconds) })
            .ToListAsync();

        var activeDays = daySeconds
            .Where(d => d.Seconds > 0)
            .Select(d => d.Day)
            .OrderBy(d => d)
            .ToHashSet();

        if (activeDays.Count == 0)
            return (0, 0);

        var best = 0;
        var run = 0;
        DateTime? prev = null;
        foreach (var day in activeDays.OrderBy(d => d))
        {
            if (prev.HasValue && day == prev.Value.AddDays(1))
                run++;
            else
                run = 1;
            best = Math.Max(best, run);
            prev = day;
        }

        // Current streak: consecutive days ending today or yesterday (UTC).
        var current = 0;
        var cursor = today;
        if (!activeDays.Contains(today))
        {
            // Allow streak to remain if last focus was yesterday (day not finished).
            if (activeDays.Contains(today.AddDays(-1)))
                cursor = today.AddDays(-1);
            else
                return (0, best);
        }

        while (activeDays.Contains(cursor))
        {
            current++;
            cursor = cursor.AddDays(-1);
        }

        return (current, best);
    }

    public async Task<List<ModeBreakdownItem>> GetModeBreakdownAsync(DateTime utcStartInclusive, DateTime utcEndExclusive)
    {
        var rows = await _dbContext.FocusSessions
            .Where(s => s.IsCompleted
                        && s.StartedAt >= utcStartInclusive
                        && s.StartedAt < utcEndExclusive)
            .GroupBy(s => s.Mode)
            .Select(g => new ModeBreakdownItem
            {
                Mode = g.Key,
                TotalSeconds = g.Sum(x => x.ElapsedSeconds),
                SessionCount = g.Count()
            })
            .ToListAsync();

        var max = rows.Count == 0 ? 0 : rows.Max(r => r.TotalSeconds);
        foreach (var row in rows)
            row.FractionOfMax = max <= 0 ? 0 : (double)row.TotalSeconds / max;

        return rows.OrderByDescending(r => r.TotalSeconds).ToList();
    }

    public async Task<List<FocusSession>> GetUnsyncedCompletedSessionsAsync()
    {
        return await _dbContext.FocusSessions
            .Where(s => s.IsCompleted && !s.IsSynced)
            .OrderBy(s => s.StartedAt)
            .ToListAsync();
    }

    public async Task MarkSessionsSyncedAsync(IEnumerable<Guid> sessionIds)
    {
        var ids = sessionIds.ToList();
        if (ids.Count == 0)
            return;

        var sessions = await _dbContext.FocusSessions
            .Where(s => ids.Contains(s.Id))
            .ToListAsync();

        foreach (var s in sessions)
            s.IsSynced = true;

        await _dbContext.SaveChangesAsync();
    }

    public async Task<bool> UpsertFromRemoteAsync(FocusSession remote)
    {
        if (remote.Id == Guid.Empty)
            remote.Id = Guid.NewGuid();

        var existing = await _dbContext.FocusSessions.FindAsync(remote.Id);
        if (existing == null)
        {
            remote.IsSynced = true;
            _dbContext.FocusSessions.Add(remote);
            await _dbContext.SaveChangesAsync();
            return true;
        }

        // LWW by elapsed: keep richer local session (protects longer local focus / journal-rich local).
        if (existing.ElapsedSeconds > remote.ElapsedSeconds)
        {
            existing.IsSynced = true;
            await _dbContext.SaveChangesAsync();
            return false;
        }

        // Prefer remote when elapsed is greater-or-equal (remote wins ties / updates).
        existing.Mode = remote.Mode;
        existing.TargetDurationSeconds = remote.TargetDurationSeconds;
        existing.ElapsedSeconds = remote.ElapsedSeconds;
        existing.StartedAt = remote.StartedAt;
        existing.CompletedAt = remote.CompletedAt;
        existing.IsCompleted = remote.IsCompleted;
        existing.IsSynced = true;

        // Only overwrite journal/energy when remote has content, or local has none.
        if (!string.IsNullOrWhiteSpace(remote.JournalNote)
            || string.IsNullOrWhiteSpace(existing.JournalNote))
        {
            existing.JournalNote = remote.JournalNote;
        }

        if (remote.EnergyRating is >= 1 and <= 5 || existing.EnergyRating is null)
            existing.EnergyRating = remote.EnergyRating;

        await _dbContext.SaveChangesAsync();
        return true;
    }
}
