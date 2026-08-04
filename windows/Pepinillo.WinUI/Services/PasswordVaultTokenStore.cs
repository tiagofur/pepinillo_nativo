using System;
using System.Threading.Tasks;
using Pepinillo.Core.Services;
using Windows.Security.Credentials;

namespace Pepinillo.WinUI.Services;

/// <summary>
/// Secure token store via Windows PasswordVault (access + refresh).
/// </summary>
public class PasswordVaultTokenStore : IAuthTokenStore
{
    private const string AccessResource = "Pepinillo.AuthAccessToken";
    private const string RefreshResource = "Pepinillo.AuthRefreshToken";
    private const string UserName = "session";

    public Task<string?> GetAccessTokenAsync() => Task.FromResult(Retrieve(AccessResource));

    public Task<string?> GetRefreshTokenAsync() => Task.FromResult(Retrieve(RefreshResource));

    public Task SetTokensAsync(string? accessToken, string? refreshToken)
    {
        Store(AccessResource, accessToken);
        Store(RefreshResource, refreshToken);
        return Task.CompletedTask;
    }

    public Task ClearAsync() => SetTokensAsync(null, null);

    private static string? Retrieve(string resource)
    {
        try
        {
            var vault = new PasswordVault();
            var credential = vault.Retrieve(resource, UserName);
            credential.RetrievePassword();
            return string.IsNullOrEmpty(credential.Password) ? null : credential.Password;
        }
        catch
        {
            return null;
        }
    }

    private static void Store(string resource, string? token)
    {
        try
        {
            var vault = new PasswordVault();
            try
            {
                var existing = vault.Retrieve(resource, UserName);
                vault.Remove(existing);
            }
            catch
            {
                // no existing credential
            }

            if (!string.IsNullOrEmpty(token))
                vault.Add(new PasswordCredential(resource, UserName, token));
        }
        catch (Exception ex)
        {
            System.Diagnostics.Debug.WriteLine($"PasswordVaultTokenStore.Store({resource}) failed: {ex.Message}");
        }
    }
}
