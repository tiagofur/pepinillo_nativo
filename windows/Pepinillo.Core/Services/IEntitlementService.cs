using System.Threading.Tasks;
using Pepinillo.Core.Models;

namespace Pepinillo.Core.Services;

/// <summary>
/// Free vs Pepinillo+/Everywhere feature gating, backed by store/backend subscription cache.
/// </summary>
public interface IEntitlementService
{
    SubscriptionStatus? CachedStatus { get; }

    EntitlementTier CurrentTier { get; }

    /// <summary>True when tier is Pepinillo+ or Everywhere/AI+.</summary>
    bool IsPremium { get; }

    bool CanUseFocusMode(FocusMode mode);

    /// <summary>Free: at most 3 incomplete root tasks.</summary>
    bool CanCreateIncompleteRootTask(int currentIncompleteRootCount);

    bool CanCreateSubtask { get; }

    bool CanUseRecurrence { get; }

    /// <summary>Free: 7 days; premium: unrestricted (int.MaxValue).</summary>
    int MaxAnalyticsHistoryDays { get; }

    /// <summary>Refreshes cache from <see cref="IStoreCommerceService"/>.</summary>
    Task RefreshAsync();

    /// <summary>Applies a known status (tests / post-purchase) without a store round-trip.</summary>
    void ApplyStatus(SubscriptionStatus status);
}
