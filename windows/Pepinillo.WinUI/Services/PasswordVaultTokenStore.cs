using System;
using System.Threading.Tasks;
using Pepinillo.Core.Services;
using Windows.Security.Credentials;

namespace Pepinillo.WinUI.Services;

/// <summary>
/// Secure token store via Windows PasswordVault (falls back to no-op clear on failure).
/// </summary>
public class PasswordVaultTokenStore : IAuthTokenStore
{
    private const string ResourceName = "Pepinillo.AuthToken";
    private const string UserName = "session";

    public Task<string?> GetTokenAsync()
    {
        try
        {
            var vault = new PasswordVault();
            var credential = vault.Retrieve(ResourceName, UserName);
            credential.RetrievePassword();
            return Task.FromResult<string?>(string.IsNullOrEmpty(credential.Password) ? null : credential.Password);
        }
        catch
        {
            return Task.FromResult<string?>(null);
        }
    }

    public Task SetTokenAsync(string? token)
    {
        try
        {
            var vault = new PasswordVault();
            try
            {
                var existing = vault.Retrieve(ResourceName, UserName);
                vault.Remove(existing);
            }
            catch
            {
                // no existing credential
            }

            if (!string.IsNullOrEmpty(token))
                vault.Add(new PasswordCredential(ResourceName, UserName, token));
        }
        catch (Exception ex)
        {
            System.Diagnostics.Debug.WriteLine($"PasswordVaultTokenStore.SetToken failed: {ex.Message}");
        }

        return Task.CompletedTask;
    }

    public Task ClearAsync() => SetTokenAsync(null);
}
