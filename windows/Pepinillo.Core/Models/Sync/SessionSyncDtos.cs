using System;
using System.Collections.Generic;
using System.Text.Json.Serialization;

namespace Pepinillo.Core.Models.Sync;

/// <summary>
/// Body for POST /sync/sessions — must wrap the sessions array (not a raw array).
/// </summary>
public sealed class SessionSyncRequest
{
    [JsonPropertyName("sessions")]
    public List<ServerFocusSessionDto> Sessions { get; set; } = new();

    [JsonPropertyName("lastSyncAt")]
    public DateTime? LastSyncAt { get; set; }
}

/// <summary>Server-shaped focus session (domain.FocusSession wire format).</summary>
public sealed class ServerFocusSessionDto
{
    [JsonPropertyName("id")]
    public string Id { get; set; } = string.Empty;

    [JsonPropertyName("startedAt")]
    public DateTime StartedAt { get; set; }

    [JsonPropertyName("endedAt")]
    public DateTime? EndedAt { get; set; }

    [JsonPropertyName("mode")]
    public string Mode { get; set; } = "pomodoro";

    [JsonPropertyName("phase")]
    public string Phase { get; set; } = "focus";

    [JsonPropertyName("durationSeconds")]
    public int DurationSeconds { get; set; }

    [JsonPropertyName("elapsedSeconds")]
    public int ElapsedSeconds { get; set; }

    [JsonPropertyName("wasCompleted")]
    public bool WasCompleted { get; set; }

    [JsonPropertyName("journalNote")]
    public string? JournalNote { get; set; }

    [JsonPropertyName("satisfactionRating")]
    public int SatisfactionRating { get; set; }

    [JsonPropertyName("pauseCount")]
    public int PauseCount { get; set; }

    [JsonPropertyName("totalPauseSeconds")]
    public int TotalPauseSeconds { get; set; }

    [JsonPropertyName("pomodoroNumber")]
    public int PomodoroNumber { get; set; }

    [JsonPropertyName("createdAt")]
    public DateTime? CreatedAt { get; set; }

    [JsonPropertyName("updatedAt")]
    public DateTime? UpdatedAt { get; set; }
}

/// <summary>Response from POST /sync/sessions.</summary>
public sealed class SessionSyncResponse
{
    [JsonPropertyName("sessions")]
    public List<ServerFocusSessionDto>? Sessions { get; set; }

    [JsonPropertyName("serverTimestamp")]
    public DateTime? ServerTimestamp { get; set; }
}

/// <summary>Client-side result for POST /sync/sessions.</summary>
public sealed class SessionSyncClientResult
{
    public bool Success { get; init; }
    public bool RequiresEverywhere { get; init; }
    public IReadOnlyList<ServerFocusSessionDto> Sessions { get; init; } = Array.Empty<ServerFocusSessionDto>();
    public string? ErrorMessage { get; init; }
    public int? StatusCode { get; init; }
}

/// <summary>Paginated page inside GET /sync/full.</summary>
public sealed class FullSyncPageDto
{
    [JsonPropertyName("items")]
    public List<ServerFocusSessionDto> Items { get; set; } = new();

    [JsonPropertyName("nextCursor")]
    public string? NextCursor { get; set; }

    [JsonPropertyName("hasMore")]
    public bool HasMore { get; set; }
}

/// <summary>GET /sync/full response (sessions page used by W10).</summary>
public sealed class FullSyncResponse
{
    [JsonPropertyName("sessions")]
    public FullSyncPageDto? Sessions { get; set; }

    [JsonPropertyName("serverTimestamp")]
    public DateTime? ServerTimestamp { get; set; }
}

/// <summary>Client-side result for GET /sync/full session pull.</summary>
public sealed class FullSyncClientResult
{
    public bool Success { get; init; }
    public bool RequiresEverywhere { get; init; }
    public IReadOnlyList<ServerFocusSessionDto> Sessions { get; init; } = Array.Empty<ServerFocusSessionDto>();
    public string? NextSessionCursor { get; init; }
    public bool HasMoreSessions { get; init; }
    public string? ErrorMessage { get; init; }
    public int? StatusCode { get; init; }
}
