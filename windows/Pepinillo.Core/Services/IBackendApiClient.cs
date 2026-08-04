using System.Collections.Generic;
using System.Threading.Tasks;
using Pepinillo.Core.Models;

namespace Pepinillo.Core.Services;

public interface IBackendApiClient
{
    bool IsAuthenticated { get; }
    string? AuthToken { get; }

    /// <summary>Restores access + refresh tokens from <see cref="IAuthTokenStore"/> if present.</summary>
    Task InitializeAsync();

    Task<bool> LoginAsync(string email, string password);
    Task<bool> RegisterAsync(string email, string password, string name);

    /// <summary>
    /// Exchanges the stored refresh token for a new access/refresh pair via POST /auth/refresh.
    /// </summary>
    Task<bool> RefreshAsync();

    Task LogoutAsync();
    Task<bool> SyncSessionsAsync(IEnumerable<FocusSession> sessions);
    Task<SubscriptionStatus> GetSubscriptionStatusAsync();
}
