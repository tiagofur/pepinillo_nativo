using System.Threading.Tasks;
using Pepinillo.Core.Models;

namespace Pepinillo.Core.Services;

/// <summary>
/// Platform-agnostic commerce logic: product IDs + backend entitlement merge.
/// WinUI overrides with StoreContext when package identity is available.
/// </summary>
public class StoreCommerceService : IStoreCommerceService
{
    public const string PepinilloPlusStoreId = ProductCatalog.PepinilloPlusStoreId;
    public const string EverywhereMonthlyStoreId = ProductCatalog.EverywhereMonthlyStoreId;
    public const string EverywhereAnnualStoreId = ProductCatalog.EverywhereAnnualStoreId;

    private readonly IBackendApiClient _backendClient;

    public SubscriptionStatus? CachedStatus { get; private set; }

    public StoreCommerceService(IBackendApiClient backendClient)
    {
        _backendClient = backendClient;
    }

    public virtual async Task<SubscriptionStatus> CheckStoreEntitlementsAsync()
    {
        // Check cross-device entitlement via Go Backend first if logged in
        if (_backendClient.IsAuthenticated)
        {
            try
            {
                var backendStatus = await _backendClient.GetSubscriptionStatusAsync();
                if (backendStatus.IsActive)
                {
                    CachedStatus = backendStatus;
                    return backendStatus;
                }
            }
            catch
            {
                // fall through to free / cache
            }
        }

        // Core default: free (no StoreContext on non-Windows / tests).
        var free = new SubscriptionStatus
        {
            Tier = EntitlementTier.Free,
            SourceStore = "MicrosoftStore"
        };
        CachedStatus = free;
        return free;
    }

    /// <summary>Allows WinUI StoreContext layer to update the shared cache.</summary>
    protected void CacheStatus(SubscriptionStatus status) => CachedStatus = status;

    public virtual Task<bool> PurchasePepinilloPlusAsync()
    {
        // Overridden by WindowsStoreCommerceService; Core returns false (no purchase surface).
        return Task.FromResult(false);
    }

    public virtual Task<bool> SubscribeEverywherePlusAsync(bool annual = false)
    {
        return Task.FromResult(false);
    }

    public bool HasPremiumEntitlement()
    {
        var tier = CachedStatus?.Tier ?? EntitlementTier.Free;
        return tier is EntitlementTier.PepinilloPlus or EntitlementTier.EverywherePlus;
    }
}
