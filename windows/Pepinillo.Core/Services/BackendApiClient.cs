using System;
using System.Collections.Generic;
using System.Linq;
using System.Net;
using System.Net.Http;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using System.Threading.Tasks;
using Pepinillo.Core.Models;
using Pepinillo.Core.Models.Sync;
using Pepinillo.Core.Utilities;

namespace Pepinillo.Core.Services;

public class BackendApiClient : IBackendApiClient
{
    private static readonly JsonSerializerOptions JsonOptions = new(JsonSerializerDefaults.Web);

    private readonly HttpClient _httpClient;
    private readonly IAuthTokenStore _tokenStore;
    private readonly ISettingsService? _settings;
    private const string BaseUrl = "https://api.pepinillo.app/v1";
    private string? _memoryDeviceId;

    public bool IsAuthenticated => !string.IsNullOrEmpty(AuthToken);
    public string? AuthToken { get; private set; }
    private string? RefreshToken { get; set; }

    public int? LastStatusCode { get; private set; }
    public string? LastError { get; private set; }

    public BackendApiClient(
        HttpClient httpClient,
        IAuthTokenStore tokenStore,
        ISettingsService? settings = null)
    {
        _httpClient = httpClient;
        _tokenStore = tokenStore;
        _settings = settings;
        _httpClient.BaseAddress = new Uri(BaseUrl);
    }

    public async Task InitializeAsync()
    {
        try
        {
            var access = await _tokenStore.GetAccessTokenAsync();
            var refresh = await _tokenStore.GetRefreshTokenAsync();
            ApplyTokens(access, refresh);
            await EnsureDeviceIdHeaderAsync();
        }
        catch
        {
            ApplyTokens(null, null);
        }
    }

    public async Task<bool> LoginAsync(string email, string password)
    {
        ClearLastError();
        try
        {
            await EnsureDeviceIdHeaderAsync();
            var payload = new { email, password };
            var response = await _httpClient.PostAsJsonAsync("/auth/login", payload, JsonOptions);
            RecordStatus(response);
            if (!response.IsSuccessStatusCode)
            {
                LastError = await BuildErrorMessageAsync(response, "Login failed");
                return false;
            }

            var ok = await TryApplyTokensFromJsonAsync(response);
            if (!ok)
                LastError = "Login response missing access token.";
            return ok;
        }
        catch (Exception ex)
        {
            LastError = $"Login error: {ex.Message}";
            return false;
        }
    }

    public async Task<bool> RegisterAsync(string email, string password, string name)
    {
        ClearLastError();
        try
        {
            await EnsureDeviceIdHeaderAsync();
            var payload = new { email, password, name };
            var response = await _httpClient.PostAsJsonAsync("/auth/register", payload, JsonOptions);
            RecordStatus(response);
            if (!response.IsSuccessStatusCode)
            {
                LastError = await BuildErrorMessageAsync(response, "Registration failed");
                return false;
            }

            // Backend returns tokens on register; persist when present.
            if (response.Content.Headers.ContentLength is > 0
                || response.Content.Headers.ContentType != null)
            {
                await TryApplyTokensFromJsonAsync(response);
            }

            return true;
        }
        catch (Exception ex)
        {
            LastError = $"Registration error: {ex.Message}";
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
            await EnsureDeviceIdHeaderAsync();
            var payload = new { refreshToken = RefreshToken };
            var response = await _httpClient.PostAsJsonAsync("/auth/refresh", payload, JsonOptions);
            RecordStatus(response);
            if (!response.IsSuccessStatusCode)
            {
                LastError = await BuildErrorMessageAsync(response, "Token refresh failed");
                return false;
            }

            return await TryApplyTokensFromJsonAsync(response);
        }
        catch (Exception ex)
        {
            LastError = $"Refresh error: {ex.Message}";
            return false;
        }
    }

    public async Task LogoutAsync()
    {
        ApplyTokens(null, null);
        ClearLastError();
        try
        {
            await _tokenStore.ClearAsync();
        }
        catch
        {
            // ignore store failures on logout
        }
    }

    public async Task<SessionSyncClientResult> SyncSessionsAsync(
        IEnumerable<FocusSession> sessions,
        DateTime? lastSyncAt = null)
    {
        ClearLastError();
        if (!IsAuthenticated)
        {
            LastError = "Not authenticated.";
            return new SessionSyncClientResult
            {
                Success = false,
                ErrorMessage = LastError,
                StatusCode = null
            };
        }

        try
        {
            await EnsureDeviceIdHeaderAsync();
            var body = BuildSessionSyncRequest(sessions, lastSyncAt);
            var response = await _httpClient.PostAsJsonAsync("/sync/sessions", body, JsonOptions);
            if (response.StatusCode == HttpStatusCode.Unauthorized)
            {
                var refreshed = await RefreshAsync();
                if (!refreshed)
                {
                    LastError = "Session expired. Sign in again.";
                    return new SessionSyncClientResult
                    {
                        Success = false,
                        ErrorMessage = LastError,
                        StatusCode = 401
                    };
                }

                response = await _httpClient.PostAsJsonAsync("/sync/sessions", body, JsonOptions);
            }

            RecordStatus(response);
            if (response.StatusCode == HttpStatusCode.Forbidden)
            {
                LastError = "Everywhere subscription required for cloud sync.";
                return new SessionSyncClientResult
                {
                    Success = false,
                    RequiresEverywhere = true,
                    ErrorMessage = LastError,
                    StatusCode = 403
                };
            }

            if (!response.IsSuccessStatusCode)
            {
                LastError = await BuildErrorMessageAsync(response, "Session push failed");
                return new SessionSyncClientResult
                {
                    Success = false,
                    ErrorMessage = LastError,
                    StatusCode = (int)response.StatusCode
                };
            }

            var payload = await response.Content.ReadFromJsonAsync<SessionSyncResponse>(JsonOptions);
            var returned = payload?.Sessions ?? new List<ServerFocusSessionDto>();
            return new SessionSyncClientResult
            {
                Success = true,
                Sessions = returned,
                StatusCode = (int)response.StatusCode
            };
        }
        catch (Exception ex)
        {
            LastError = $"Sync error: {ex.Message}";
            return new SessionSyncClientResult
            {
                Success = false,
                ErrorMessage = LastError
            };
        }
    }

    public async Task<FullSyncClientResult> PullSessionsAsync(int limit = 100, string? sessionCursor = null)
    {
        ClearLastError();
        if (!IsAuthenticated)
        {
            LastError = "Not authenticated.";
            return new FullSyncClientResult
            {
                Success = false,
                ErrorMessage = LastError
            };
        }

        try
        {
            await EnsureDeviceIdHeaderAsync();
            var path = $"/sync/full?limit={Math.Clamp(limit, 1, 100)}";
            if (!string.IsNullOrWhiteSpace(sessionCursor))
                path += $"&sessionCursor={Uri.EscapeDataString(sessionCursor)}";

            var response = await _httpClient.GetAsync(path);
            if (response.StatusCode == HttpStatusCode.Unauthorized)
            {
                if (await RefreshAsync())
                    response = await _httpClient.GetAsync(path);
            }

            RecordStatus(response);
            if (response.StatusCode == HttpStatusCode.Forbidden)
            {
                LastError = "Everywhere subscription required for cloud sync.";
                return new FullSyncClientResult
                {
                    Success = false,
                    RequiresEverywhere = true,
                    ErrorMessage = LastError,
                    StatusCode = 403
                };
            }

            if (!response.IsSuccessStatusCode)
            {
                LastError = await BuildErrorMessageAsync(response, "Session pull failed");
                return new FullSyncClientResult
                {
                    Success = false,
                    ErrorMessage = LastError,
                    StatusCode = (int)response.StatusCode
                };
            }

            var payload = await response.Content.ReadFromJsonAsync<FullSyncResponse>(JsonOptions);
            var page = payload?.Sessions;
            var items = page?.Items ?? new List<ServerFocusSessionDto>();
            return new FullSyncClientResult
            {
                Success = true,
                Sessions = items,
                NextSessionCursor = page?.NextCursor,
                HasMoreSessions = page?.HasMore ?? false,
                StatusCode = (int)response.StatusCode
            };
        }
        catch (Exception ex)
        {
            LastError = $"Pull error: {ex.Message}";
            return new FullSyncClientResult
            {
                Success = false,
                ErrorMessage = LastError
            };
        }
    }

    public async Task<SubscriptionStatus> GetSubscriptionStatusAsync()
    {
        if (!IsAuthenticated) return new SubscriptionStatus { Tier = EntitlementTier.Free };

        try
        {
            await EnsureDeviceIdHeaderAsync();
            var response = await _httpClient.GetAsync("/user/subscription");
            if (response.StatusCode == HttpStatusCode.Unauthorized)
            {
                if (await RefreshAsync())
                    response = await _httpClient.GetAsync("/user/subscription");
            }

            RecordStatus(response);
            if (response.IsSuccessStatusCode)
            {
                var status = await response.Content.ReadFromJsonAsync<SubscriptionStatus>(JsonOptions);
                return status ?? new SubscriptionStatus { Tier = EntitlementTier.Free };
            }

            LastError = await BuildErrorMessageAsync(response, "Subscription status failed");
        }
        catch (Exception ex)
        {
            LastError = $"Subscription error: {ex.Message}";
            // Fallback to Free on network offline
        }

        return new SubscriptionStatus { Tier = EntitlementTier.Free };
    }

    internal static SessionSyncRequest BuildSessionSyncRequest(
        IEnumerable<FocusSession> sessions,
        DateTime? lastSyncAt)
    {
        return new SessionSyncRequest
        {
            Sessions = sessions.Select(FocusSessionSyncMapper.ToServer).ToList(),
            LastSyncAt = lastSyncAt
        };
    }

    /// <summary>
    /// Parses nested <c>tokens.accessToken</c> / <c>tokens.refreshToken</c>,
    /// with legacy root <c>token</c> / <c>accessToken</c> fallback.
    /// </summary>
    private async Task<bool> TryApplyTokensFromJsonAsync(HttpResponseMessage response)
    {
        var result = await response.Content.ReadFromJsonAsync<JsonElement>(JsonOptions);
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

    private async Task EnsureDeviceIdHeaderAsync()
    {
        var deviceId = await GetOrCreateDeviceIdAsync();
        if (_httpClient.DefaultRequestHeaders.Contains("X-Device-ID"))
            _httpClient.DefaultRequestHeaders.Remove("X-Device-ID");
        _httpClient.DefaultRequestHeaders.TryAddWithoutValidation("X-Device-ID", deviceId);
    }

    private async Task<string> GetOrCreateDeviceIdAsync()
    {
        if (_settings != null)
        {
            try
            {
                var settings = await _settings.GetSettingsAsync();
                if (string.IsNullOrWhiteSpace(settings.DeviceId))
                {
                    settings.DeviceId = Guid.NewGuid().ToString("N");
                    await _settings.SaveSettingsAsync(settings);
                }

                return settings.DeviceId!;
            }
            catch
            {
                // fall through to memory id
            }
        }

        _memoryDeviceId ??= Guid.NewGuid().ToString("N");
        return _memoryDeviceId;
    }

    private void RecordStatus(HttpResponseMessage response) =>
        LastStatusCode = (int)response.StatusCode;

    private void ClearLastError()
    {
        LastError = null;
        LastStatusCode = null;
    }

    private static async Task<string> BuildErrorMessageAsync(HttpResponseMessage response, string prefix)
    {
        var status = (int)response.StatusCode;
        string? body = null;
        try
        {
            body = await response.Content.ReadAsStringAsync();
            if (body.Length > 200)
                body = body[..200];
        }
        catch
        {
            // ignore body read failures
        }

        return string.IsNullOrWhiteSpace(body)
            ? $"{prefix} (HTTP {status})."
            : $"{prefix} (HTTP {status}): {body}";
    }
}
