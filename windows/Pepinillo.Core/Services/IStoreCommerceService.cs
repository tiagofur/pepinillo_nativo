using System.Threading.Tasks;
using Pepinillo.Core.Models;

namespace Pepinillo.Core.Services;

public interface IStoreCommerceService
{
    SubscriptionStatus? CachedStatus { get; }

    Task<SubscriptionStatus> CheckStoreEntitlementsAsync();
    Task<bool> PurchasePepinilloPlusAsync();
    Task<bool> SubscribeEverywherePlusAsync(bool annual = false);

    /// <summary>True when tier is Pepinillo+ or Everywhere (premium soundscapes, etc.).</summary>
    bool HasPremiumEntitlement();
}
