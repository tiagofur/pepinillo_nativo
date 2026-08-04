using System;
using System.Threading.Tasks;
using Pepinillo.Core.Models;

namespace Pepinillo.Core.Services;

/// <summary>
/// Tracks one streak-protection skip per ISO week on <see cref="UserSettings"/>.
/// Auto-consume is performed by <see cref="FocusSessionService.GetStreaksAsync"/> when bridging a gap.
/// </summary>
public sealed class StreakProtectionService : IStreakProtectionService
{
    public const int MaxSkipsPerWeek = 1;

    private readonly ISettingsService _settings;
    private readonly IEntitlementService _entitlements;

    public StreakProtectionService(ISettingsService settings, IEntitlementService entitlements)
    {
        _settings = settings;
        _entitlements = entitlements;
    }

    public DateTime GetIsoWeekStartUtc(DateTime utcNow)
    {
        var day = utcNow.Kind == DateTimeKind.Utc ? utcNow.Date : DateTime.SpecifyKind(utcNow.Date, DateTimeKind.Utc);
        // ISO week: Monday = start. DayOfWeek Sunday=0 … Saturday=6 → Mon=0 … Sun=6
        var offset = ((int)day.DayOfWeek + 6) % 7;
        return day.AddDays(-offset);
    }

    public async Task<bool> CanUseSkipAsync(DateTime utcNow)
    {
        if (!_entitlements.IsPremium)
            return false;

        var settings = await EnsureWeekAsync(utcNow).ConfigureAwait(false);
        return settings.StreakProtectionUsesThisWeek < MaxSkipsPerWeek;
    }

    public async Task<bool> TryConsumeSkipAsync(DateTime utcNow)
    {
        if (!_entitlements.IsPremium)
            return false;

        var settings = await EnsureWeekAsync(utcNow).ConfigureAwait(false);
        if (settings.StreakProtectionUsesThisWeek >= MaxSkipsPerWeek)
            return false;

        settings.StreakProtectionUsesThisWeek += 1;
        await _settings.SaveSettingsAsync(settings).ConfigureAwait(false);
        return true;
    }

    public Task<bool> CanBridgeGapThisWeekAsync(DateTime gapDayUtc, DateTime evaluationTodayUtc)
    {
        // Premium-only. Walk enforces one bridge per ISO week via bridgesByWeek.
        _ = gapDayUtc;
        _ = evaluationTodayUtc;
        return Task.FromResult(_entitlements.IsPremium);
    }

    public async Task<bool> EnsureBridgedAndConsumeAsync(DateTime gapDayUtc, DateTime evaluationTodayUtc)
    {
        if (!_entitlements.IsPremium)
            return false;

        // Gap-week multiplicity is enforced by the streak walk (bridgesByWeek).
        // Persist at most one consume against the *evaluation* ISO week so Analytics
        // shows "used this week" after any auto-bridge that preserves the current streak.
        _ = gapDayUtc;
        var settings = await EnsureWeekAsync(evaluationTodayUtc).ConfigureAwait(false);
        if (settings.StreakProtectionUsesThisWeek < MaxSkipsPerWeek)
        {
            settings.StreakProtectionUsesThisWeek += 1;
            await _settings.SaveSettingsAsync(settings).ConfigureAwait(false);
        }

        return true;
    }

    public async Task<StreakProtectionStatus> GetStatusAsync(DateTime utcNow)
    {
        if (!_entitlements.IsPremium)
        {
            return new StreakProtectionStatus
            {
                IsPremium = false,
                Available = false,
                UsedThisWeek = false,
                Caption = "Upgrade for streak protection (1 skip / week)"
            };
        }

        var settings = await EnsureWeekAsync(utcNow).ConfigureAwait(false);
        var used = settings.StreakProtectionUsesThisWeek >= MaxSkipsPerWeek;
        return new StreakProtectionStatus
        {
            IsPremium = true,
            Available = !used,
            UsedThisWeek = used,
            Caption = used
                ? "Streak protection: used this week"
                : "Streak protection: available (1 / week)"
        };
    }

    private async Task<UserSettings> EnsureWeekAsync(DateTime utcNow)
    {
        var weekStart = GetIsoWeekStartUtc(utcNow);
        var settings = await _settings.GetSettingsAsync().ConfigureAwait(false);
        var stored = settings.StreakProtectionWeekStartUtc?.Date;
        if (stored != weekStart)
        {
            settings.StreakProtectionWeekStartUtc = weekStart;
            settings.StreakProtectionUsesThisWeek = 0;
            await _settings.SaveSettingsAsync(settings).ConfigureAwait(false);
        }

        return settings;
    }
}
