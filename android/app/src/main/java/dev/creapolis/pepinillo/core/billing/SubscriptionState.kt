package dev.creapolis.pepinillo.core.billing

enum class SubscriptionTier {
    FREE,
    PEPINILLO_PLUS,
    EVERYWHERE_MONTHLY,
    EVERYWHERE_ANNUAL,
    EVERYWHERE_LIFETIME;

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
            || tier == SubscriptionTier.EVERYWHERE_LIFETIME

    /** True when the user holds a Pepinillo+ one-time entitlement (enum-based). */
    val isPepinilloPlus: Boolean
        get() = tier == SubscriptionTier.PEPINILLO_PLUS

    /** Backwards-compat alias — prefer hasLocalPremium at new call sites. */
    val isPro: Boolean get() = hasLocalPremium
}

object PepinilloProducts {
    const val PEPINILLO_PLUS = "com.pepinillo.app.pepinillo_plus"
    const val EVERYWHERE_MONTHLY = "com.pepinillo.app.everywhere.monthly"
    const val EVERYWHERE_ANNUAL = "com.pepinillo.app.everywhere.annual"
    const val EVERYWHERE_LIFETIME = "com.pepinillo.app.everywhere.lifetime"

    val ALL_IDS = listOf(PEPINILLO_PLUS, EVERYWHERE_MONTHLY, EVERYWHERE_ANNUAL, EVERYWHERE_LIFETIME)

    fun tierForProduct(productId: String): SubscriptionTier = when {
        productId == EVERYWHERE_LIFETIME || productId.contains("everywhere") && productId.contains("lifetime") ->
            SubscriptionTier.EVERYWHERE_LIFETIME
        productId == EVERYWHERE_ANNUAL || productId.contains("everywhere") && productId.contains("annual") ->
            SubscriptionTier.EVERYWHERE_ANNUAL
        productId == EVERYWHERE_MONTHLY || productId.contains("everywhere") && productId.contains("monthly") ->
            SubscriptionTier.EVERYWHERE_MONTHLY
        productId == PEPINILLO_PLUS || productId.contains("pepinillo_plus") ->
            SubscriptionTier.PEPINILLO_PLUS
        else -> SubscriptionTier.FREE
    }
}
