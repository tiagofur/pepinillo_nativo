using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using Pepinillo.Core.Models;

namespace Pepinillo.Core.Services;

public interface IFocusSessionService
{
    Task SaveSessionAsync(FocusSession session);
    Task<List<FocusSession>> GetRecentSessionsAsync(int count = 20);
    Task<int> GetTodayFocusMinutesAsync();
}
