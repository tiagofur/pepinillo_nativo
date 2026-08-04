using System.Threading.Tasks;
using Pepinillo.Core.Models;

namespace Pepinillo.Core.Services;

/// <summary>
/// Caches last <see cref="SubscriptionStatus"/> from commerce and evaluates FREE vs Plus limits.
/// </summary>
public class EntitlementService : IEntitlementService
{
    public const int FreeMaxIncompleteRootTasks = 3;
    public const int FreeAnalyticsHistoryDays = 7;

    private readonly IStoreCommerceService _commerce;
    private SubscriptionStatus? _overrideStatus;

    public EntitlementService(IStoreCommerceService commerce)
    {
        _commerce = commerce;
    }

    public SubscriptionStatus? CachedStatus => _overrideStatus ?? _commerce.CachedStatus;

    public EntitlementTier CurrentTier => CachedStatus?.Tier ?? EntitlementTier.Free;

    public bool IsPremium =>
        CurrentTier is EntitlementTier.PepinilloPlus or EntitlementTier.EverywherePlus;

    public bool CanUseFocusMode(FocusMode mode) =>
        IsPremium || mode is FocusMode.Pomodoro or FocusMode.Stopwatch;

    public bool CanCreateIncompleteRootTask(int currentIncompleteRootCount) =>
        IsPremium || currentIncompleteRootCount < FreeMaxIncompleteRootTasks;

    public bool CanCreateSubtask => IsPremium;

    public bool CanUseRecurrence => IsPremium;

    public int MaxAnalyticsHistoryDays => IsPremium ? int.MaxValue : FreeAnalyticsHistoryDays;

    public bool CanUseTheme(string themeName) =>
        IsPremium || AppThemeCatalog.IsFreeTheme(themeName);

    public async Task RefreshAsync()
    {
        _overrideStatus = null;
        await _commerce.CheckStoreEntitlementsAsync();
    }

    public void ApplyStatus(SubscriptionStatus status)
    {
        _overrideStatus = status;
    }
}
