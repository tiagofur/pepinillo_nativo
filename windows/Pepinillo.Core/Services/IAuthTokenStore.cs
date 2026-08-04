using System.Threading.Tasks;

namespace Pepinillo.Core.Services;

/// <summary>
/// Platform-agnostic auth token persistence. Core default is in-memory; WinUI overrides with secure store.
/// </summary>
public interface IAuthTokenStore
{
    Task<string?> GetTokenAsync();
    Task SetTokenAsync(string? token);
    Task ClearAsync();
}
