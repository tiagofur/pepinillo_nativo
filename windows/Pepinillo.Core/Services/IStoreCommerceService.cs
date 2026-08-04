using System.Threading.Tasks;
using Pepinillo.Core.Models;

namespace Pepinillo.Core.Services;

public interface IStoreCommerceService
{
    SubscriptionStatus? CachedStatus { get; }

    /// <summary>Last commerce failure message for paywall / diagnostics (null when last op succeeded).</summary>
    string? LastError { get; }

    Task<SubscriptionStatus> CheckStoreEntitlementsAsync();

    /// <summary>
    /// Re-scans store licenses and/or backend subscription and refreshes the cache.
    /// </summary>
    Task<SubscriptionStatus> RestorePurchasesAsync();

    Task<CommerceResult> PurchasePepinilloPlusAsync();

    Task<CommerceResult> SubscribeEverywherePlusAsync(bool annual = false);

    /// <summary>True when tier is Pepinillo+ or Everywhere (premium soundscapes, etc.).</summary>
    bool HasPremiumEntitlement();
}
