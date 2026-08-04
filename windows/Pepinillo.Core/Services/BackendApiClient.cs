using System;
using System.Collections.Generic;
using System.Net;
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
    private string? RefreshToken { get; set; }

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
            var access = await _tokenStore.GetAccessTokenAsync();
            var refresh = await _tokenStore.GetRefreshTokenAsync();
            ApplyTokens(access, refresh);
        }
        catch
        {
            ApplyTokens(null, null);
        }
    }

    public async Task<bool> LoginAsync(string email, string password)
    {
        try
        {
            var payload = new { email, password };
            var response = await _httpClient.PostAsJsonAsync("/auth/login", payload);
            if (!response.IsSuccessStatusCode) return false;

            return await TryApplyTokensFromJsonAsync(response);
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
            if (!response.IsSuccessStatusCode) return false;

            // Backend returns tokens on register; persist when present.
            if (response.Content.Headers.ContentLength is > 0
                || response.Content.Headers.ContentType != null)
            {
                await TryApplyTokensFromJsonAsync(response);
            }

            return true;
        }
        catch
        {
            return false;
        }
    }

    public async Task<bool> RefreshAsync()
    {
        if (string.IsNullOrEmpty(RefreshToken))
        {
            try
            {
                RefreshToken = await _tokenStore.GetRefreshTokenAsync();
            }
            catch
            {
                return false;
            }
        }

        if (string.IsNullOrEmpty(RefreshToken))
            return false;

        try
        {
            var payload = new { refreshToken = RefreshToken };
            var response = await _httpClient.PostAsJsonAsync("/auth/refresh", payload);
            if (!response.IsSuccessStatusCode) return false;

            return await TryApplyTokensFromJsonAsync(response);
        }
        catch
        {
            return false;
        }
    }

    public async Task LogoutAsync()
    {
        ApplyTokens(null, null);
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
            if (response.StatusCode == HttpStatusCode.Unauthorized)
            {
                var refreshed = await RefreshAsync();
                if (!refreshed) return false;

                response = await _httpClient.PostAsJsonAsync("/sync/sessions", sessions);
            }

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
            if (response.StatusCode == HttpStatusCode.Unauthorized)
            {
                if (await RefreshAsync())
                    response = await _httpClient.GetAsync("/user/subscription");
            }

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

    /// <summary>
    /// Parses nested <c>tokens.accessToken</c> / <c>tokens.refreshToken</c>,
    /// with legacy root <c>token</c> / <c>accessToken</c> fallback.
    /// </summary>
    private async Task<bool> TryApplyTokensFromJsonAsync(HttpResponseMessage response)
    {
        var result = await response.Content.ReadFromJsonAsync<JsonElement>();
        if (result.ValueKind is JsonValueKind.Undefined or JsonValueKind.Null)
            return false;

        string? access = null;
        string? refresh = null;

        if (result.TryGetProperty("tokens", out var tokens)
            && tokens.ValueKind == JsonValueKind.Object)
        {
            if (tokens.TryGetProperty("accessToken", out var nestedAccess))
                access = nestedAccess.GetString();
            if (tokens.TryGetProperty("refreshToken", out var nestedRefresh))
                refresh = nestedRefresh.GetString();
        }

        // Legacy / alternate shapes
        if (string.IsNullOrEmpty(access) && result.TryGetProperty("token", out var legacyToken))
            access = legacyToken.GetString();
        if (string.IsNullOrEmpty(access) && result.TryGetProperty("accessToken", out var rootAccess))
            access = rootAccess.GetString();
        if (string.IsNullOrEmpty(refresh) && result.TryGetProperty("refreshToken", out var rootRefresh))
            refresh = rootRefresh.GetString();

        if (string.IsNullOrEmpty(access))
            return false;

        ApplyTokens(access, refresh);
        try
        {
            await _tokenStore.SetTokensAsync(access, refresh);
        }
        catch
        {
            // still treat login as success if Bearer is applied in-memory
        }

        return true;
    }

    private void ApplyTokens(string? accessToken, string? refreshToken)
    {
        AuthToken = accessToken;
        RefreshToken = refreshToken;
        if (string.IsNullOrEmpty(accessToken))
            _httpClient.DefaultRequestHeaders.Authorization = null;
        else
            _httpClient.DefaultRequestHeaders.Authorization =
                new AuthenticationHeaderValue("Bearer", accessToken);
    }
}
