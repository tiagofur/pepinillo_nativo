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

/**
 * Merges a server-reported subscription into the current (RevenueCat-backed) state (B4).
 *
 * The server profile can be stale — e.g. `/users/me` fetched right after a purchase whose
 * receipt verification failed — so it must never clobber an RC-confirmed entitlement:
 *
 *  - A `free` server response is ignored while an RC entitlement is active
 *    ([SubscriptionState.hasLocalPremium]); it only applies when RC has no active
 *    entitlement.
 *  - A paid server tier replaces the current tier, and the expiration only ever EXTENDS
 *    (the later of current/server; a null expiry means "no known expiry" and is kept).
 */
fun mergeServerSubscription(
    current: SubscriptionState,
    serverTier: SubscriptionTier,
    serverExpiresAt: Long?,
): SubscriptionState {
    if (serverTier == SubscriptionTier.FREE && current.hasLocalPremium) {
        // RC just confirmed (or still holds) an active entitlement — a stale "free"
        // profile must not downgrade it.
        return current
    }
    val mergedExpiry = listOfNotNull(current.expirationDate, serverExpiresAt).maxOrNull()
    return SubscriptionState(
        tier = serverTier,
        expirationDate = mergedExpiry,
    )
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
