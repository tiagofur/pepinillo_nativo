using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using Pepinillo.Core.Models;

namespace Pepinillo.Core.Services;

public interface IFocusSessionService
{
    Task SaveSessionAsync(FocusSession session);
    Task UpdateJournalAsync(Guid sessionId, string? journalNote, int? energyRating);
    Task<List<FocusSession>> GetRecentSessionsAsync(int count = 20);
    Task<List<FocusSession>> GetSessionsInRangeAsync(DateTime utcStartInclusive, DateTime utcEndExclusive);
    Task<int> GetTodayFocusMinutesAsync(DateTime? utcNow = null);
    Task<int> GetTotalFocusSecondsAsync(DateTime utcStartInclusive, DateTime utcEndExclusive);
    Task<(int CurrentStreak, int BestStreak)> GetStreaksAsync(DateTime? utcToday = null);
    Task<List<ModeBreakdownItem>> GetModeBreakdownAsync(DateTime utcStartInclusive, DateTime utcEndExclusive);
    Task<List<FocusSession>> GetUnsyncedCompletedSessionsAsync();
    Task MarkSessionsSyncedAsync(IEnumerable<Guid> sessionIds);
}
