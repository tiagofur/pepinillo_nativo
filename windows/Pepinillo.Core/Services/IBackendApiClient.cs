using System.Collections.Generic;
using System.Threading.Tasks;
using Pepinillo.Core.Models;

namespace Pepinillo.Core.Services;

public interface IBackendApiClient
{
    bool IsAuthenticated { get; }
    string? AuthToken { get; }

    /// <summary>Restores token from <see cref="IAuthTokenStore"/> if present.</summary>
    Task InitializeAsync();

    Task<bool> LoginAsync(string email, string password);
    Task<bool> RegisterAsync(string email, string password, string name);
    Task LogoutAsync();
    Task<bool> SyncSessionsAsync(IEnumerable<FocusSession> sessions);
    Task<SubscriptionStatus> GetSubscriptionStatusAsync();
}
