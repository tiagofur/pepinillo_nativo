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
    private readonly IAuthTokenStore _tokenStore;
    private const string BaseUrl = "https://api.pepinillo.app/v1";

    public bool IsAuthenticated => !string.IsNullOrEmpty(AuthToken);
    public string? AuthToken { get; private set; }

    public BackendApiClient(HttpClient httpClient, IAuthTokenStore tokenStore)
    {
        _httpClient = httpClient;
        _tokenStore = tokenStore;
        _httpClient.BaseAddress = new Uri(BaseUrl);
    }

    public async Task InitializeAsync()
    {
        try
        {
            var token = await _tokenStore.GetTokenAsync();
            ApplyToken(token);
        }
        catch
        {
            ApplyToken(null);
        }
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
                var token = tokenProp.GetString();
                ApplyToken(token);
                await _tokenStore.SetTokenAsync(token);
                return !string.IsNullOrEmpty(token);
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

    public async Task LogoutAsync()
    {
        ApplyToken(null);
        try
        {
            await _tokenStore.ClearAsync();
        }
        catch
        {
            // ignore store failures on logout
        }
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

    private void ApplyToken(string? token)
    {
        AuthToken = token;
        if (string.IsNullOrEmpty(token))
            _httpClient.DefaultRequestHeaders.Authorization = null;
        else
            _httpClient.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);
    }
}
