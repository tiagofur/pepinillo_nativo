using System.Threading.Tasks;

namespace Pepinillo.Core.Services;

/// <summary>
/// Platform-agnostic auth token persistence (access + refresh).
/// Core default is in-memory; WinUI overrides with secure store.
/// </summary>
public interface IAuthTokenStore
{
    Task<string?> GetAccessTokenAsync();
    Task<string?> GetRefreshTokenAsync();

    /// <summary>
    /// Persists both tokens. Passing null for a token clears that slot.
    /// </summary>
    Task SetTokensAsync(string? accessToken, string? refreshToken);

    Task ClearAsync();
}
