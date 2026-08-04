using System;
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

    public string? LastError { get; protected set; }

    public StoreCommerceService(IBackendApiClient backendClient)
    {
        _backendClient = backendClient;
    }

    public virtual async Task<SubscriptionStatus> CheckStoreEntitlementsAsync()
    {
        LastError = null;
        var backend = await TryGetBackendStatusAsync();
        // Core default store surface: free (no StoreContext on non-Windows / tests).
        var store = CreateFreeStatus();
        var merged = MergeStatuses(backend, store);
        CacheStatus(merged);
        return merged;
    }

    /// <summary>
    /// Core restore re-runs entitlement check (backend + free). WinUI overrides with license re-scan.
    /// </summary>
    public virtual async Task<SubscriptionStatus> RestorePurchasesAsync()
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

    /// <summary>Allows WinUI StoreContext layer to update the shared cache.</summary>
    protected void CacheStatus(SubscriptionStatus status) => CachedStatus = status;

    /// <summary>
    /// Prefers highest tier: Everywhere &gt; Pepinillo+ &gt; Free.
    /// When equal tier, prefers the first non-null with a richer source label.
    /// </summary>
    public static SubscriptionStatus MergeStatuses(SubscriptionStatus? primary, SubscriptionStatus? secondary)
    {
        if (primary == null && secondary == null)
            return CreateFreeStatus();
        if (primary == null)
            return secondary!;
        if (secondary == null)
            return primary;

        var primaryRank = TierRank(primary.Tier);
        var secondaryRank = TierRank(secondary.Tier);
        if (primaryRank > secondaryRank)
            return primary;
        if (secondaryRank > primaryRank)
            return secondary;

        // Same rank: prefer active expiration-aware entry, else primary.
        if (!primary.IsActive && secondary.IsActive)
            return secondary;
        return primary;
    }

    public static int TierRank(EntitlementTier tier) =>
        tier switch
        {
            EntitlementTier.EverywherePlus => 2,
            EntitlementTier.PepinilloPlus => 1,
            _ => 0
        };

    protected async Task<SubscriptionStatus?> TryGetBackendStatusAsync()
    {
        if (!_backendClient.IsAuthenticated)
            return null;

        try
        {
            var backendStatus = await _backendClient.GetSubscriptionStatusAsync();
            if (!backendStatus.IsActive && !string.IsNullOrWhiteSpace(_backendClient.LastError))
                LastError = _backendClient.LastError;
            // Normalize source when backend omits it.
            if (string.IsNullOrWhiteSpace(backendStatus.SourceStore))
                backendStatus.SourceStore = "Backend";
            return backendStatus;
        }
        catch (Exception ex)
        {
            LastError = $"Backend subscription check failed: {ex.Message}";
            return null;
        }
    }

    protected static SubscriptionStatus CreateFreeStatus() =>
        new()
        {
            Tier = EntitlementTier.Free,
            SourceStore = "MicrosoftStore"
        };

    public virtual Task<CommerceResult> PurchasePepinilloPlusAsync()
    {
        LastError = "Store purchases require the Microsoft Store install.";
        return Task.FromResult(CommerceResult.Fail(LastError));
    }

    public virtual Task<CommerceResult> SubscribeEverywherePlusAsync(bool annual = false)
    {
        LastError = "Store subscriptions require the Microsoft Store install.";
        return Task.FromResult(CommerceResult.Fail(LastError));
    }

    public bool HasPremiumEntitlement()
    {
        var tier = CachedStatus?.Tier ?? EntitlementTier.Free;
        return tier is EntitlementTier.PepinilloPlus or EntitlementTier.EverywherePlus;
    }
}
