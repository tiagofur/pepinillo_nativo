package dev.creapolis.pepinillo.core.billing

enum class SubscriptionTier {
    FREE, PRO_MONTHLY, PRO_YEARLY, LIFETIME;

    val isPro: Boolean get() = this != FREE
}

data class SubscriptionState(
    val tier: SubscriptionTier = SubscriptionTier.FREE,
    val activeProductId: String? = null,
    val expirationDate: Long? = null,
) {
    val isPro: Boolean get() = tier.isPro
}

object PepinilloProducts {
    const val MONTHLY = "com.pepinillo.app.pro.monthly"
    const val ANNUAL = "com.pepinillo.app.pro.annual"
    const val LIFETIME = "com.pepinillo.app.pro.lifetime"

    val SUBSCRIPTION_IDS = listOf(MONTHLY, ANNUAL)
    val INAPP_IDS = listOf(LIFETIME)
    val ALL_IDS = SUBSCRIPTION_IDS + INAPP_IDS

    fun tierForProduct(productId: String): SubscriptionTier = when {
        productId.contains("lifetime") -> SubscriptionTier.LIFETIME
        productId.contains("annual") || productId.contains("yearly") -> SubscriptionTier.PRO_YEARLY
        productId.contains("monthly") || productId.contains("month") -> SubscriptionTier.PRO_MONTHLY
        else -> SubscriptionTier.FREE
    }
}
