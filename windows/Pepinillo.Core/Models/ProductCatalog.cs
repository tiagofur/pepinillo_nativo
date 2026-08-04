namespace Pepinillo.Core.Models;

/// <summary>
/// Microsoft Store product IDs and display prices (decision D1 — see windows/store/LAUNCH_CHECKLIST.md).
/// Pepinillo+ is Windows-scoped durable ($9.99). Everywhere matches global mobile to avoid cross-platform arbitrage.
/// Partner Center is source of truth for billed price; these strings are UI defaults.
/// </summary>
public static class ProductCatalog
{
    public const string PepinilloPlusStoreId = "pepinillo_plus_windows";
    public const string EverywhereMonthlyStoreId = "everywhere_plus_monthly";
    public const string EverywhereAnnualStoreId = "everywhere_plus_annual";

    /// <summary>Windows-only Pepinillo+ durable (platform-scoped).</summary>
    public const string PepinilloPlusPriceDisplay = "$9.99";

    /// <summary>Matches global mobile Everywhere monthly (cross-platform entitlement).</summary>
    public const string EverywhereMonthlyPriceDisplay = "$4.99/mo";

    /// <summary>Matches global mobile Everywhere annual (cross-platform entitlement).</summary>
    public const string EverywhereAnnualPriceDisplay = "$34.99/yr";

    public const string PriceDisclaimer =
        "Store prices may vary by market. Everywhere plans match mobile so your subscription works across devices.";
}
