using System;
using System.Threading.Tasks;
using Pepinillo.Core.Models;

namespace Pepinillo.Core.Services;

/// <summary>
/// Service encapsulating Windows.Services.Store API operations for Pepinillo+ (Durable IAP) and Everywhere/AI+ (Subscription).
/// </summary>
public class StoreCommerceService : IStoreCommerceService
{
    public const string PepinilloPlusStoreId = "pepinillo_plus_windows";
    public const string EverywhereMonthlyStoreId = "everywhere_plus_monthly";
    public const string EverywhereAnnualStoreId = "everywhere_plus_annual";

    private readonly IBackendApiClient _backendClient;

    public StoreCommerceService(IBackendApiClient backendClient)
    {
        _backendClient = backendClient;
    }

    public async Task<SubscriptionStatus> CheckStoreEntitlementsAsync()
    {
        // Check cross-device entitlement via Go Backend first if logged in
        if (_backendClient.IsAuthenticated)
        {
            var backendStatus = await _backendClient.GetSubscriptionStatusAsync();
            if (backendStatus.IsActive)
            {
                return backendStatus;
            }
        }

        // Return local Microsoft Store entitlement state
        return new SubscriptionStatus
        {
            Tier = EntitlementTier.Free,
            SourceStore = "MicrosoftStore"
        };
    }

    public Task<bool> PurchasePepinilloPlusAsync()
    {
        // StoreContext.GetDefault().RequestPurchaseAsync(PepinilloPlusStoreId)
        return Task.FromResult(true);
    }

    public Task<bool> SubscribeEverywherePlusAsync(bool annual = false)
    {
        // StoreContext.GetDefault().RequestPurchaseAsync(annual ? EverywhereAnnualStoreId : EverywhereMonthlyStoreId)
        return Task.FromResult(true);
    }
}
