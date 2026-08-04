using System;
using Pepinillo.Core.Models;
using Pepinillo.Core.Models.Sync;

namespace Pepinillo.Core.Utilities;

/// <summary>Maps local <see cref="FocusSession"/> ↔ server DTOs for Everywhere sync.</summary>
public static class FocusSessionSyncMapper
{
    public static ServerFocusSessionDto ToServer(FocusSession session)
    {
        ArgumentNullException.ThrowIfNull(session);

        return new ServerFocusSessionDto
        {
            Id = session.Id == Guid.Empty ? Guid.NewGuid().ToString() : session.Id.ToString(),
            StartedAt = EnsureUtc(session.StartedAt),
            EndedAt = session.CompletedAt.HasValue ? EnsureUtc(session.CompletedAt.Value) : null,
            Mode = FocusModeSyncMapper.ToServer(session.Mode),
            Phase = "focus",
            DurationSeconds = session.TargetDurationSeconds,
            ElapsedSeconds = session.ElapsedSeconds,
            WasCompleted = session.IsCompleted,
            JournalNote = session.JournalNote ?? string.Empty,
            SatisfactionRating = session.EnergyRating ?? 0,
            PauseCount = 0,
            TotalPauseSeconds = 0,
            PomodoroNumber = 0
        };
    }

    public static FocusSession ToLocal(ServerFocusSessionDto dto)
    {
        ArgumentNullException.ThrowIfNull(dto);

        var id = Guid.TryParse(dto.Id, out var parsed) ? parsed : Guid.NewGuid();
        var started = EnsureUtc(dto.StartedAt);
        DateTime? ended = dto.EndedAt.HasValue ? EnsureUtc(dto.EndedAt.Value) : null;

        int? energy = dto.SatisfactionRating is >= 1 and <= 5
            ? dto.SatisfactionRating
            : null;

        return new FocusSession
        {
            Id = id,
            Mode = FocusModeSyncMapper.ToLocal(dto.Mode),
            TargetDurationSeconds = dto.DurationSeconds,
            ElapsedSeconds = dto.ElapsedSeconds,
            StartedAt = started,
            CompletedAt = ended,
            IsCompleted = dto.WasCompleted || ended.HasValue,
            IsSynced = true,
            JournalNote = string.IsNullOrWhiteSpace(dto.JournalNote) ? null : dto.JournalNote,
            EnergyRating = energy
        };
    }

    private static DateTime EnsureUtc(DateTime value) =>
        value.Kind switch
        {
            DateTimeKind.Utc => value,
            DateTimeKind.Local => value.ToUniversalTime(),
            _ => DateTime.SpecifyKind(value, DateTimeKind.Utc)
        };
}
