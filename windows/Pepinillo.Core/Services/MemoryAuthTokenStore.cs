using System.Threading.Tasks;

namespace Pepinillo.Core.Services;

/// <summary>
/// In-memory token store for tests and non-Windows hosts.
/// </summary>
public class MemoryAuthTokenStore : IAuthTokenStore
{
    private string? _token;

    public Task<string?> GetTokenAsync() => Task.FromResult(_token);

    public Task SetTokenAsync(string? token)
    {
        _token = token;
        return Task.CompletedTask;
    }

    public Task ClearAsync()
    {
        _token = null;
        return Task.CompletedTask;
    }
}
