using System;
using System.Collections.Generic;
using System.Net.Http;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using System.Threading.Tasks;
using Pepinillo.Core.Models;

namespace Pepinillo.Core.Services;

public class BackendApiClient : IBackendApiClient
{
    private readonly HttpClient _httpClient;
    private const string BaseUrl = "https://api.pepinillo.app/v1";

    public bool IsAuthenticated => !string.IsNullOrEmpty(AuthToken);
    public string? AuthToken { get; private set; }

    public BackendApiClient(HttpClient httpClient)
    {
        _httpClient = httpClient;
        _httpClient.BaseAddress = new Uri(BaseUrl);
    }

    public async Task<bool> LoginAsync(string email, string password)
    {
        try
        {
            var payload = new { email, password };
            var response = await _httpClient.PostAsJsonAsync("/auth/login", payload);
            if (!response.IsSuccessStatusCode) return false;

            var result = await response.Content.ReadFromJsonAsync<JsonElement>();
            if (result.TryGetProperty("token", out var tokenProp))
            {
                AuthToken = tokenProp.GetString();
                _httpClient.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", AuthToken);
                return true;
            }
            return false;
        }
        catch
        {
            return false;
        }
    }

    public async Task<bool> RegisterAsync(string email, string password, string name)
    {
        try
        {
            var payload = new { email, password, name };
            var response = await _httpClient.PostAsJsonAsync("/auth/register", payload);
            return response.IsSuccessStatusCode;
        }
        catch
        {
            return false;
        }
    }

    public Task LogoutAsync()
    {
        AuthToken = null;
        _httpClient.DefaultRequestHeaders.Authorization = null;
        return Task.CompletedTask;
    }

    public async Task<bool> SyncSessionsAsync(IEnumerable<FocusSession> sessions)
    {
        if (!IsAuthenticated) return false;
        try
        {
            var response = await _httpClient.PostAsJsonAsync("/sync/sessions", sessions);
            return response.IsSuccessStatusCode;
        }
        catch
        {
            return false;
        }
    }

    public async Task<SubscriptionStatus> GetSubscriptionStatusAsync()
    {
        if (!IsAuthenticated) return new SubscriptionStatus { Tier = EntitlementTier.Free };

        try
        {
            var response = await _httpClient.GetAsync("/user/subscription");
            if (response.IsSuccessStatusCode)
            {
                var status = await response.Content.ReadFromJsonAsync<SubscriptionStatus>();
                return status ?? new SubscriptionStatus { Tier = EntitlementTier.Free };
            }
        }
        catch
        {
            // Fallback to Free on network offline
        }

        return new SubscriptionStatus { Tier = EntitlementTier.Free };
    }
}
