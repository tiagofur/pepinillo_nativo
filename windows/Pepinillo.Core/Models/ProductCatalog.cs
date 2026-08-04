namespace Pepinillo.Core.Models;

/// <summary>
/// Placeholder Microsoft Store product display prices (D1 open — not final).
/// Aligns with PRD 11 Windows pricing placeholders.
/// </summary>
public static class ProductCatalog
{
    public const string PepinilloPlusStoreId = "pepinillo_plus_windows";
    public const string EverywhereMonthlyStoreId = "everywhere_plus_monthly";
    public const string EverywhereAnnualStoreId = "everywhere_plus_annual";

    /// <summary>Display-only placeholder; actual Store price may differ (decision D1).</summary>
    public const string PepinilloPlusPriceDisplay = "$9.99";

    /// <summary>Display-only placeholder; actual Store price may differ (decision D1).</summary>
    public const string EverywhereMonthlyPriceDisplay = "$2.99/mo";

    /// <summary>Display-only placeholder; actual Store price may differ (decision D1).</summary>
    public const string EverywhereAnnualPriceDisplay = "$19.99/yr";

    public const string PriceDisclaimer =
        "Prices shown are placeholders and may change before Store launch (product decision D1).";
}
