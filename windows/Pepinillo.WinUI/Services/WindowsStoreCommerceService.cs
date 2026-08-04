using System;
using System.Threading.Tasks;
using Pepinillo.Core.Models;
using Pepinillo.Core.Services;
using Windows.Services.Store;
using WinRT.Interop;

namespace Pepinillo.WinUI.Services;

/// <summary>
/// StoreContext IAP path. Falls back to backend/free when package identity is missing (dev unpackaged / non-Store).
/// </summary>
public class WindowsStoreCommerceService : StoreCommerceService
{
    private const string StoreIdentityUnavailableMessage =
        "Store identity unavailable (sideload/dev). Use free tier or Partner Center sandbox.";

    private const string NetworkPurchaseMessage =
        "Store network or server error. Check your connection and try again.";

    private const string CancelledPurchaseMessage = "Purchase cancelled.";

    public WindowsStoreCommerceService(IBackendApiClient backendClient) : base(backendClient)
    {
    }

    public override async Task<SubscriptionStatus> CheckStoreEntitlementsAsync()
    {
        LastError = null;
        var backend = await TryGetBackendStatusAsync();
        var store = await ScanStoreLicensesAsync();
        var merged = MergeStatuses(backend, store ?? CreateFreeStatus());
        CacheStatus(merged);
        return merged;
    }

    public override async Task<SubscriptionStatus> RestorePurchasesAsync()
    {
        LastError = null;
        try
        {
            return await CheckStoreEntitlementsAsync();
        }
        catch (Exception ex)
        {
            LastError = $"Restore failed: {ex.Message}";
            var free = CreateFreeStatus();
            CacheStatus(free);
            return free;
        }
    }

    public override async Task<CommerceResult> PurchasePepinilloPlusAsync()
    {
        return await RequestPurchaseAsync(
            ProductCatalog.PepinilloPlusStoreId,
            successMessage: "Purchase successful.");
    }

    public override async Task<CommerceResult> SubscribeEverywherePlusAsync(bool annual = false)
    {
        var storeId = annual
            ? ProductCatalog.EverywhereAnnualStoreId
            : ProductCatalog.EverywhereMonthlyStoreId;
        return await RequestPurchaseAsync(
            storeId,
            successMessage: "Subscription successful.");
    }

    private async Task<CommerceResult> RequestPurchaseAsync(string storeId, string successMessage)
    {
        LastError = null;
        try
        {
            var context = CreateStoreContext();
            var result = await context.RequestPurchaseAsync(storeId);
            return await MapPurchaseStatusAsync(result, successMessage);
        }
        catch (Exception ex)
        {
            // Missing package identity / unpackaged often surfaces as exceptions.
            var message = LooksLikeIdentityFailure(ex)
                ? StoreIdentityUnavailableMessage
                : $"Purchase error: {ex.Message}";
            LastError = message;
            return CommerceResult.Fail(message);
        }
    }

    private async Task<CommerceResult> MapPurchaseStatusAsync(
        StorePurchaseResult result,
        string successMessage)
    {
        switch (result.Status)
        {
            case StorePurchaseStatus.Succeeded:
            case StorePurchaseStatus.AlreadyPurchased:
            {
                var status = await CheckStoreEntitlementsAsync();
                return CommerceResult.Ok(successMessage, status);
            }
            case StorePurchaseStatus.NotPurchased:
            {
                LastError = CancelledPurchaseMessage;
                return CommerceResult.Fail(CancelledPurchaseMessage);
            }
            case StorePurchaseStatus.NetworkError:
            case StorePurchaseStatus.ServerError:
            {
                LastError = NetworkPurchaseMessage;
                return CommerceResult.Fail(NetworkPurchaseMessage);
            }
            default:
            {
                var extended = result.ExtendedError?.Message;
                var message = string.IsNullOrWhiteSpace(extended)
                    ? $"Purchase failed ({result.Status})."
                    : $"Purchase failed: {extended}";
                LastError = message;
                return CommerceResult.Fail(message);
            }
        }
    }

    /// <summary>
    /// Scans active add-on licenses. Prefers Everywhere when both Plus and Everywhere are present.
    /// </summary>
    private async Task<SubscriptionStatus?> ScanStoreLicensesAsync()
    {
        try
        {
            var context = CreateStoreContext();
            var license = await context.GetAppLicenseAsync();
            if (license?.AddOnLicenses == null)
                return null;

            SubscriptionStatus? plus = null;
            SubscriptionStatus? everywhere = null;

            foreach (var pair in license.AddOnLicenses)
            {
                var addOn = pair.Value;
                if (addOn == null || !addOn.IsActive)
                    continue;

                var key = (pair.Key ?? string.Empty) + " " + (addOn.InAppOfferToken ?? string.Empty);

                if (key.Contains("everywhere", StringComparison.OrdinalIgnoreCase)
                    || key.Contains(ProductCatalog.EverywhereMonthlyStoreId, StringComparison.OrdinalIgnoreCase)
                    || key.Contains(ProductCatalog.EverywhereAnnualStoreId, StringComparison.OrdinalIgnoreCase))
                {
                    everywhere = new SubscriptionStatus
                    {
                        Tier = EntitlementTier.EverywherePlus,
                        SourceStore = "MicrosoftStore",
                        ExpirationDate = addOn.ExpirationDate.UtcDateTime
                    };
                    continue;
                }

                if (key.Contains("pepinillo_plus", StringComparison.OrdinalIgnoreCase)
                    || key.Contains(ProductCatalog.PepinilloPlusStoreId, StringComparison.OrdinalIgnoreCase))
                {
                    plus = new SubscriptionStatus
                    {
                        Tier = EntitlementTier.PepinilloPlus,
                        SourceStore = "MicrosoftStore",
                        ExpirationDate = addOn.ExpirationDate.UtcDateTime
                    };
                }
            }

            return MergeStatuses(everywhere, plus);
        }
        catch (Exception ex)
        {
            System.Diagnostics.Debug.WriteLine($"StoreContext entitlement check failed: {ex.Message}");
            if (LooksLikeIdentityFailure(ex))
                LastError ??= StoreIdentityUnavailableMessage;
            return null;
        }
    }

    /// <summary>
    /// WinUI often requires InitializeWithWindow so purchase dialogs can parent correctly.
    /// </summary>
    private static StoreContext CreateStoreContext()
    {
        var context = StoreContext.GetDefault();
        try
        {
            var window = App.MainWindowInstance;
            if (window != null)
            {
                var hwnd = WindowNative.GetWindowHandle(window);
                InitializeWithWindow.Initialize(context, hwnd);
            }
        }
        catch (Exception ex)
        {
            System.Diagnostics.Debug.WriteLine($"StoreContext InitializeWithWindow skipped: {ex.Message}");
        }

        return context;
    }

    private static bool LooksLikeIdentityFailure(Exception ex)
    {
        var text = ex.ToString();
        return text.Contains("0x803F6107", StringComparison.OrdinalIgnoreCase)
               || text.Contains("package identity", StringComparison.OrdinalIgnoreCase)
               || text.Contains("no store", StringComparison.OrdinalIgnoreCase)
               || text.Contains("StoreContext", StringComparison.OrdinalIgnoreCase)
                  && text.Contains("not available", StringComparison.OrdinalIgnoreCase);
    }
}
