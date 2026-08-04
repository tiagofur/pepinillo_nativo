using System.Threading.Tasks;

namespace Pepinillo.Core.Services;

/// <summary>
/// In-memory token store for tests and non-Windows hosts.
/// </summary>
public class MemoryAuthTokenStore : IAuthTokenStore
{
    private string? _accessToken;
    private string? _refreshToken;

    public Task<string?> GetAccessTokenAsync() => Task.FromResult(_accessToken);

    public Task<string?> GetRefreshTokenAsync() => Task.FromResult(_refreshToken);

    public Task SetTokensAsync(string? accessToken, string? refreshToken)
    {
        _accessToken = accessToken;
        _refreshToken = refreshToken;
        return Task.CompletedTask;
    }

    public Task ClearAsync()
    {
        _accessToken = null;
        _refreshToken = null;
        return Task.CompletedTask;
    }
}
