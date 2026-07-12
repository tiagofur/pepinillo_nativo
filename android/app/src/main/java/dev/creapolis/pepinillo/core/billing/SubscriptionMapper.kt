package dev.creapolis.pepinillo.core.billing

import com.revenuecat.purchases.CustomerInfo
import com.revenuecat.purchases.models.StoreTransaction

private val SUPPORTED_ENTITLEMENT_IDS = listOf(
    "everywhere_plus",
    "pepinillo_plus",
    "premium",
    "pro",
)

private const val GRACE_PERIOD_MS = 3L * 24 * 60 * 60 * 1000

data class PurchaseVerificationTarget(
    val productId: String,
    val purchaseToken: String,
)

/** Maps RevenueCat [CustomerInfo] to local [SubscriptionState] with expiration enforcement. */
fun subscriptionStateFromCustomerInfo(customerInfo: CustomerInfo): SubscriptionState {
    val activeEntitlementId = SUPPORTED_ENTITLEMENT_IDS.firstOrNull { id ->
        customerInfo.entitlements[id]?.isActive == true
    } ?: return SubscriptionState()

    val activeProductId = resolveActiveProductId(customerInfo)
    val tier = resolveTier(activeEntitlementId, activeProductId)
    val entitlement = customerInfo.entitlements[activeEntitlementId]
    val expirationMillis = entitlement?.expirationDate?.time

    if (tier == SubscriptionTier.EVERYWHERE_MONTHLY || tier == SubscriptionTier.EVERYWHERE_ANNUAL) {
        if (expirationMillis != null) {
            val now = System.currentTimeMillis()
            if (now > expirationMillis + GRACE_PERIOD_MS) {
                return SubscriptionState()
            }
        }
    }

    return SubscriptionState(
        tier = tier,
        activeProductId = activeProductId,
        expirationDate = expirationMillis,
    )
}

fun resolveActiveProductId(customerInfo: CustomerInfo): String? {
    return customerInfo.activeSubscriptions.firstOrNull { productId ->
        productId in PepinilloProducts.ALL_IDS
    } ?: customerInfo.nonSubscriptionTransactions
        .map { it.productIdentifier }
        .firstOrNull { productId -> productId in PepinilloProducts.ALL_IDS }
}

private fun resolveTier(activeEntitlementId: String, activeProductId: String?): SubscriptionTier {
    if (activeProductId != null) {
        val mappedTier = PepinilloProducts.tierForProduct(activeProductId)
        if (mappedTier != SubscriptionTier.FREE) return mappedTier
    }

    return when (activeEntitlementId) {
        "everywhere_plus" -> SubscriptionTier.EVERYWHERE_MONTHLY
        "pepinillo_plus" -> SubscriptionTier.PEPINILLO_PLUS
        "premium", "pro" -> SubscriptionTier.PEPINILLO_PLUS
        else -> SubscriptionTier.FREE
    }
}

fun purchaseVerificationTarget(
    customerInfo: CustomerInfo,
    productId: String?,
    storeTransaction: StoreTransaction? = null,
): PurchaseVerificationTarget? {
    val resolvedProductId = productId ?: resolveActiveProductId(customerInfo) ?: return null

    // Purchase token is only available from the purchase callback's StoreTransaction.
    // CustomerInfo (including restore) does not expose tokens in RevenueCat 8.x.
    return storeTransaction?.purchaseToken
        ?.takeIf { it.isNotBlank() }
        ?.let { token -> PurchaseVerificationTarget(resolvedProductId, token) }
}

object PaywallPolicy {
    /** Auto-dismiss only when the user already owns the selected (or superset) entitlement. */
    fun shouldAutoDismiss(state: SubscriptionState, selectedProductId: String?): Boolean {
        val selected = selectedProductId ?: return false
        return when {
            PepinilloProducts.isEverywhereProduct(selected) -> state.canSync
            PepinilloProducts.isLifetimeProduct(selected) -> state.isPepinilloPlus || state.canSync
            else -> false
        }
    }
}