using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using Pepinillo.Core.Models;
using Pepinillo.Core.Models.Sync;

namespace Pepinillo.Core.Services;

public interface IBackendApiClient
{
    bool IsAuthenticated { get; }
    string? AuthToken { get; }

    /// <summary>Last HTTP status from the most recent API call (auth/sync/subscription).</summary>
    int? LastStatusCode { get; }

    /// <summary>Human-readable last error surface for Account UX.</summary>
    string? LastError { get; }

    /// <summary>Restores access + refresh tokens from <see cref="IAuthTokenStore"/> if present.</summary>
    Task InitializeAsync();

    Task<bool> LoginAsync(string email, string password);
    Task<bool> RegisterAsync(string email, string password, string name);

    /// <summary>
    /// Exchanges the stored refresh token for a new access/refresh pair via POST /auth/refresh.
    /// </summary>
    Task<bool> RefreshAsync();

    Task LogoutAsync();

    /// <summary>
    /// POST /sync/sessions with wrapped <see cref="SessionSyncRequest"/> body (mapped DTOs).
    /// </summary>
    Task<SessionSyncClientResult> SyncSessionsAsync(
        IEnumerable<FocusSession> sessions,
        DateTime? lastSyncAt = null);

    /// <summary>GET /sync/full — pull sessions page (W10 minimum).</summary>
    Task<FullSyncClientResult> PullSessionsAsync(int limit = 100, string? sessionCursor = null);

    Task<SubscriptionStatus> GetSubscriptionStatusAsync();
}
