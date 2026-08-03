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
        }

        await _dbContext.SaveChangesAsync();
    }

    public async Task<List<FocusSession>> GetRecentSessionsAsync(int count = 20)
    {
        return await _dbContext.FocusSessions
            .OrderByDescending(s => s.StartedAt)
            .Take(count)
            .ToListAsync();
    }

    public async Task<int> GetTodayFocusMinutesAsync()
    {
        var today = DateTime.UtcNow.Date;
        var totalSeconds = await _dbContext.FocusSessions
            .Where(s => s.IsCompleted && s.StartedAt >= today)
            .SumAsync(s => (int?)s.ElapsedSeconds) ?? 0;
        return totalSeconds / 60;
    }
}
