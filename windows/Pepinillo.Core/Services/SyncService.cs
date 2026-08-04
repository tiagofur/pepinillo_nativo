using System;
using System.Linq;
using System.Threading.Tasks;
using Pepinillo.Core.Models;

namespace Pepinillo.Core.Services;

/// <summary>
/// Local-first sync: push unsynced completed sessions when authenticated; pull subscription status.
/// </summary>
public class SyncService : ISyncService
{
    private readonly IBackendApiClient _backend;
    private readonly IFocusSessionService _sessions;
    private readonly IStoreCommerceService _commerce;

    public SyncService(
        IBackendApiClient backend,
        IFocusSessionService sessions,
        IStoreCommerceService commerce)
    {
        _backend = backend;
        _sessions = sessions;
        _commerce = commerce;
    }

    public async Task<SyncResult> SyncNowAsync()
    {
        var result = new SyncResult();

        try
        {
            await _backend.InitializeAsync();
        }
        catch
        {
            // ignore
        }

        if (!_backend.IsAuthenticated)
        {
            result.Success = false;
            result.WasAuthenticated = false;
            result.Message = "Not signed in — local data only.";
            return result;
        }

        result.WasAuthenticated = true;

        try
        {
            var unsynced = await _sessions.GetUnsyncedCompletedSessionsAsync();
            if (unsynced.Count > 0)
            {
                var pushed = await _backend.SyncSessionsAsync(unsynced);
                if (pushed)
                {
                    await _sessions.MarkSessionsSyncedAsync(unsynced.Select(s => s.Id));
                    result.SessionsPushed = unsynced.Count;
                }
                else
                {
                    result.Success = false;
                    result.Message = "Session push failed (network or server).";
                    return result;
                }
            }

            var status = await _commerce.CheckStoreEntitlementsAsync();
            result.Subscription = status;
            result.Success = true;
            result.Message = result.SessionsPushed > 0
                ? $"Synced {result.SessionsPushed} session(s)."
                : "Already up to date.";
        }
        catch (Exception ex)
        {
            result.Success = false;
            result.Message = $"Sync error: {ex.Message}";
        }

        return result;
    }
}
