package dev.creapolis.pepinillo.core.billing

enum class SubscriptionTier {
    FREE,
    PEPINILLO_PLUS,
    EVERYWHERE_MONTHLY,
    EVERYWHERE_ANNUAL;

    /** True for any paid tier — both Pepinillo+ and all Everywhere+ variants. */
    val isPro: Boolean get() = this != FREE
}

data class SubscriptionState(
    val tier: SubscriptionTier = SubscriptionTier.FREE,
    val activeProductId: String? = null,
    val expirationDate: Long? = null,
) {
    /** Any paid user (Pepinillo+ OR any Everywhere+ tier). */
    val hasLocalPremium: Boolean
        get() = tier != SubscriptionTier.FREE

    /** Only Everywhere+ subscribers can sync to the backend. */
    val canSync: Boolean
        get() = tier == SubscriptionTier.EVERYWHERE_MONTHLY
            || tier == SubscriptionTier.EVERYWHERE_ANNUAL

    /** True when the user holds a Pepinillo+ one-time entitlement (enum-based). */
    val isPepinilloPlus: Boolean
        get() = tier == SubscriptionTier.PEPINILLO_PLUS

    /** Backwards-compat alias — prefer hasLocalPremium at new call sites. */
    val isPro: Boolean get() = hasLocalPremium
}

object PepinilloProducts {
    const val PEPINILLO_PLUS = "com.pepinillo.app.pro.lifetime"
    const val EVERYWHERE_MONTHLY = "com.pepinillo.app.pro.monthly"
    const val EVERYWHERE_ANNUAL = "com.pepinillo.app.pro.annual"

    val ALL_IDS = listOf(PEPINILLO_PLUS, EVERYWHERE_MONTHLY, EVERYWHERE_ANNUAL)

    fun isEverywhereProduct(productId: String): Boolean =
        productId == EVERYWHERE_MONTHLY ||
            productId == EVERYWHERE_ANNUAL ||
            productId.contains("monthly") ||
            productId.contains("annual")

    fun isLifetimeProduct(productId: String): Boolean =
        productId == PEPINILLO_PLUS || productId.contains("lifetime")

    fun tierForProduct(productId: String): SubscriptionTier = when (productId) {
        EVERYWHERE_ANNUAL -> SubscriptionTier.EVERYWHERE_ANNUAL
        EVERYWHERE_MONTHLY -> SubscriptionTier.EVERYWHERE_MONTHLY
        PEPINILLO_PLUS -> SubscriptionTier.PEPINILLO_PLUS
        else -> {
            // Fallback for string contains logic if RC returns slightly different IDs
            when {
                productId.contains("annual") -> SubscriptionTier.EVERYWHERE_ANNUAL
                productId.contains("monthly") -> SubscriptionTier.EVERYWHERE_MONTHLY
                productId.contains("lifetime") -> SubscriptionTier.PEPINILLO_PLUS
                else -> SubscriptionTier.FREE
            }
        }
    }
}
