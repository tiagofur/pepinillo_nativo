using System;
using System.Threading.Tasks;
using Pepinillo.Core.Models;
using Pepinillo.Core.Services;
using Windows.Services.Store;

namespace Pepinillo.WinUI.Services;

/// <summary>
/// StoreContext IAP path. Falls back to backend/free when package identity is missing (dev unpackaged / non-Store).
/// </summary>
public class WindowsStoreCommerceService : StoreCommerceService
{
    public WindowsStoreCommerceService(IBackendApiClient backendClient) : base(backendClient)
    {
    }

    public override async Task<SubscriptionStatus> CheckStoreEntitlementsAsync()
    {
        var baseStatus = await base.CheckStoreEntitlementsAsync();
        if (baseStatus.IsActive)
            return baseStatus;

        try
        {
            var context = StoreContext.GetDefault();
            var license = await context.GetAppLicenseAsync();
            if (license?.AddOnLicenses == null)
                return baseStatus;

            foreach (var pair in license.AddOnLicenses)
            {
                var addOn = pair.Value;
                if (addOn == null || !addOn.IsActive)
                    continue;

                var key = (pair.Key ?? string.Empty) + " " + (addOn.InAppOfferToken ?? string.Empty);
                if (key.Contains("pepinillo_plus", StringComparison.OrdinalIgnoreCase)
                    || key.Contains(ProductCatalog.PepinilloPlusStoreId, StringComparison.OrdinalIgnoreCase))
                {
                    var plus = new SubscriptionStatus
                    {
                        Tier = EntitlementTier.PepinilloPlus,
                        SourceStore = "MicrosoftStore",
                        ExpirationDate = addOn.ExpirationDate.UtcDateTime
                    };
                    CacheStatus(plus);
                    return plus;
                }

                if (key.Contains("everywhere", StringComparison.OrdinalIgnoreCase))
                {
                    var everywhere = new SubscriptionStatus
                    {
                        Tier = EntitlementTier.EverywherePlus,
                        SourceStore = "MicrosoftStore",
                        ExpirationDate = addOn.ExpirationDate.UtcDateTime
                    };
                    CacheStatus(everywhere);
                    return everywhere;
                }
            }
        }
        catch (Exception ex)
        {
            System.Diagnostics.Debug.WriteLine($"StoreContext entitlement check failed: {ex.Message}");
        }

        return baseStatus;
    }

    public override async Task<bool> PurchasePepinilloPlusAsync()
    {
        try
        {
            var context = StoreContext.GetDefault();
            var result = await context.RequestPurchaseAsync(ProductCatalog.PepinilloPlusStoreId);
            var ok = result.Status is StorePurchaseStatus.Succeeded or StorePurchaseStatus.AlreadyPurchased;
            if (ok)
            {
                CacheStatus(new SubscriptionStatus
                {
                    Tier = EntitlementTier.PepinilloPlus,
                    SourceStore = "MicrosoftStore"
                });
            }
            return ok;
        }
        catch (Exception ex)
        {
            System.Diagnostics.Debug.WriteLine($"Purchase Pepinillo+ failed: {ex.Message}");
            return false;
        }
    }

    public override async Task<bool> SubscribeEverywherePlusAsync(bool annual = false)
    {
        try
        {
            var storeId = annual
                ? ProductCatalog.EverywhereAnnualStoreId
                : ProductCatalog.EverywhereMonthlyStoreId;
            var context = StoreContext.GetDefault();
            var result = await context.RequestPurchaseAsync(storeId);
            var ok = result.Status is StorePurchaseStatus.Succeeded or StorePurchaseStatus.AlreadyPurchased;
            if (ok)
            {
                CacheStatus(new SubscriptionStatus
                {
                    Tier = EntitlementTier.EverywherePlus,
                    SourceStore = "MicrosoftStore"
                });
            }
            return ok;
        }
        catch (Exception ex)
        {
            System.Diagnostics.Debug.WriteLine($"Subscribe Everywhere failed: {ex.Message}");
            return false;
        }
    }
}
