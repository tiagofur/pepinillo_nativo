using System;
using System.Linq;
using System.Threading.Tasks;
using Pepinillo.Core.Models;
using Pepinillo.Core.Utilities;

namespace Pepinillo.Core.Services;

/// <summary>
/// Local-first sync: push unsynced completed sessions (wrapped body), pull remote sessions,
/// refresh subscription. Cloud sync requires Everywhere on the server.
/// </summary>
public class SyncService : ISyncService
{
    private readonly IBackendApiClient _backend;
    private readonly IFocusSessionService _sessions;
    private readonly IStoreCommerceService _commerce;
    private readonly ISettingsService _settings;

    public SyncService(
        IBackendApiClient backend,
        IFocusSessionService sessions,
        IStoreCommerceService commerce,
        ISettingsService settings)
    {
        _backend = backend;
        _sessions = sessions;
        _commerce = commerce;
        _settings = settings;
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
            result.Message =
                "Cloud sync needs Everywhere. Local data always works. Sign in with an Everywhere account to sync.";
            return result;
        }

        result.WasAuthenticated = true;

        try
        {
            var userSettings = await _settings.GetSettingsAsync();
            var lastSyncAt = userSettings.LastSyncAtUtc;

            var unsynced = await _sessions.GetUnsyncedCompletedSessionsAsync();
            if (unsynced.Count > 0)
            {
                var push = await _backend.SyncSessionsAsync(unsynced, lastSyncAt);
                if (push.RequiresEverywhere)
                {
                    result.Success = false;
                    result.RequiresEverywhere = true;
                    result.Message = "Everywhere subscription required for cloud sync.";
                    return result;
                }

                if (!push.Success)
                {
                    result.Success = false;
                    result.Message = push.ErrorMessage
                        ?? _backend.LastError
                        ?? "Session push failed (network or server).";
                    return result;
                }

                await _sessions.MarkSessionsSyncedAsync(unsynced.Select(s => s.Id));
                result.SessionsPushed = unsynced.Count;

                // Server may return sessions updated since lastSyncAt — merge them.
                foreach (var dto in push.Sessions)
                {
                    var local = FocusSessionSyncMapper.ToLocal(dto);
                    if (await _sessions.UpsertFromRemoteAsync(local))
                        result.SessionsPulled++;
                }
            }

            var pull = await _backend.PullSessionsAsync(limit: 100);
            if (pull.RequiresEverywhere)
            {
                // Push may have succeeded; still surface subscription gate for pull.
                result.RequiresEverywhere = true;
                if (result.SessionsPushed == 0)
                {
                    result.Success = false;
                    result.Message = "Everywhere subscription required for cloud sync.";
                    return result;
                }
            }
            else if (pull.Success)
            {
                foreach (var dto in pull.Sessions)
                {
                    var local = FocusSessionSyncMapper.ToLocal(dto);
                    if (await _sessions.UpsertFromRemoteAsync(local))
                        result.SessionsPulled++;
                }
            }
            else if (result.SessionsPushed == 0)
            {
                result.Success = false;
                result.Message = pull.ErrorMessage
                    ?? _backend.LastError
                    ?? "Session pull failed (network or server).";
                return result;
            }

            userSettings.LastSyncAtUtc = DateTime.UtcNow;
            await _settings.SaveSettingsAsync(userSettings);

            var status = await _commerce.CheckStoreEntitlementsAsync();
            result.Subscription = status;
            result.Success = true;
            result.Message = BuildSuccessMessage(result);
        }
        catch (Exception ex)
        {
            result.Success = false;
            result.Message = $"Sync error: {ex.Message}";
        }

        return result;
    }

    private static string BuildSuccessMessage(SyncResult result)
    {
        if (result.SessionsPushed == 0 && result.SessionsPulled == 0)
            return "Already up to date.";

        return $"Synced: pushed {result.SessionsPushed}, pulled {result.SessionsPulled}.";
    }
}
