package dev.creapolis.pepinillo.core.billing

import android.app.Activity
import android.content.Context
import android.util.Log
import com.revenuecat.purchases.Package
import com.revenuecat.purchases.PurchaseParams
import com.revenuecat.purchases.Purchases
import com.revenuecat.purchases.PurchasesConfiguration
import com.revenuecat.purchases.getOfferingsWith
import com.revenuecat.purchases.getCustomerInfoWith
import com.revenuecat.purchases.purchaseWith
import dagger.hilt.android.qualifiers.ApplicationContext
import dev.creapolis.pepinillo.BuildConfig
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.suspendCancellableCoroutine
import javax.inject.Inject
import javax.inject.Singleton
import kotlin.coroutines.resume

private const val TAG = "SubscriptionManager"
private const val REVENUECAT_API_KEY = BuildConfig.REVENUECAT_API_KEY

private val SUPPORTED_ENTITLEMENT_IDS = listOf(
    "everywhere_plus",
    "pepinillo_plus",
    // Legacy fallbacks while RevenueCat migration rolls out.
    "premium",
    "pro",
)

data class ProductInfo(
    val productId: String,
    val title: String,
    val description: String,
    val formattedPrice: String,
    val priceMicros: Long,
    val billingPeriod: String?,
    val `package`: Package,
)

@Singleton
class SubscriptionManager @Inject constructor(
    @ApplicationContext private val context: Context,
) {

    private val _subscriptionState = MutableStateFlow(SubscriptionState())
    val subscriptionState: StateFlow<SubscriptionState> = _subscriptionState.asStateFlow()

    private val _products = MutableStateFlow<List<ProductInfo>>(emptyList())
    val products: StateFlow<List<ProductInfo>> = _products.asStateFlow()

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
    private var isInitialized = false

    init {
        initializeRevenueCat()
    }

    private fun initializeRevenueCat() {
        if (isInitialized) return
        try {
            // Check if already configured (by Application class)
            if (Purchases.isConfigured) {
                isInitialized = true
                checkEntitlements()
                return
            }
            Purchases.configure(PurchasesConfiguration.Builder(context, REVENUECAT_API_KEY).build())
            Log.d(TAG, "RevenueCat initialized in Manager")
            isInitialized = true
            checkEntitlements()
        } catch (e: Exception) {
            Log.e(TAG, "Failed to initialize RevenueCat: ${e.message}", e)
        }
    }

    suspend fun connect() {
        // RevenueCat is initialized in init block
        if (!isInitialized) {
            initializeRevenueCat()
        }
    }

    suspend fun queryProducts() {
        if (!isInitialized) connect()

        suspendCancellableCoroutine { cont ->
            try {
                Purchases.sharedInstance.getOfferingsWith(
                    onError = { error ->
                        Log.e(TAG, "Failed to load offerings: ${error.message}")
                        if (cont.isActive) cont.resume(Unit)
                    },
                    onSuccess = { offerings ->
                        val allProducts = mutableListOf<ProductInfo>()

                        // Use only the current (active) offering to avoid duplicates
                        // when the same products appear across multiple offerings.
                        val targetOffering = offerings.current
                            ?: offerings["default"]
                            ?: run {
                                Log.w(TAG, "No current or default offering found")
                                null
                            }

                        targetOffering?.availablePackages?.forEach { pkg ->
                            val product = pkg.product
                            allProducts.add(
                                ProductInfo(
                                    productId = product.id,
                                    title = product.title,
                                    description = product.description,
                                    formattedPrice = product.price.formatted,
                                    priceMicros = (product.price.amountMicros),
                                    billingPeriod = when (product.period?.unit?.name) {
                                        "MONTH" -> "P1M"
                                        "YEAR" -> "P1Y"
                                        else -> null
                                    },
                                    `package` = pkg,
                                ),
                            )
                        }

                        _products.value = allProducts
                        Log.d(TAG, "Loaded ${allProducts.size} products from offering '${targetOffering?.identifier}'")
                        if (cont.isActive) cont.resume(Unit)
                    },
                )
            } catch (e: Exception) {
                Log.e(TAG, "Exception loading offerings: ${e.message}", e)
                if (cont.isActive) cont.resume(Unit)
            }
        }
    }

    fun launchPurchaseFlow(activity: Activity, product: ProductInfo) {
        scope.launch {
            suspendCancellableCoroutine { cont ->
                Purchases.sharedInstance.purchaseWith(
                    purchaseParams = PurchaseParams.Builder(activity, product.`package`).build(),
                    onSuccess = { _, customerInfo ->
                        Log.d(TAG, "Purchase successful for ${product.productId}")
                        scope.launch { checkExistingPurchases() }
                        if (cont.isActive) cont.resume(Unit)
                    },
                    onError = { error, userCancelled ->
                        Log.e(TAG, "Purchase failed: ${error.message}")
                        if (cont.isActive) cont.resume(Unit)
                    },
                )
            }
        }
    }

    private fun checkEntitlements() {
        scope.launch {
            suspendCancellableCoroutine { cont ->
                Purchases.sharedInstance.getCustomerInfoWith(
                    onError = { error ->
                        Log.e(TAG, "Failed to get customer info: ${error.message}")
                        if (cont.isActive) cont.resume(Unit)
                    },
                    onSuccess = { customerInfo ->
                        val activeEntitlementId = resolveActiveEntitlementId(customerInfo)
                        if (activeEntitlementId != null) {
                            val activeProductId = resolveActiveProductId(customerInfo)
                            val tier = resolveTier(activeEntitlementId, activeProductId)
                            _subscriptionState.value = SubscriptionState(
                                tier = tier,
                                activeProductId = activeProductId,
                            )
                            Log.d(
                                TAG,
                                "Subscription active: entitlement=$activeEntitlementId tier=$tier product=${activeProductId ?: "n/a"}",
                            )
                        } else {
                            _subscriptionState.value = SubscriptionState()
                            Log.d(TAG, "No active supported entitlement")
                        }

                        if (cont.isActive) cont.resume(Unit)
                    },
                )
            }
        }
    }

    suspend fun checkExistingPurchases() {
        if (!isInitialized) connect()

        suspendCancellableCoroutine { cont ->
            try {
                Purchases.sharedInstance.invalidateCustomerInfoCache()
                checkEntitlements()
                // Small delay to allow checkEntitlements to complete
                scope.launch {
                    kotlinx.coroutines.delay(500)
                    if (cont.isActive) cont.resume(Unit)
                }
            } catch (e: Exception) {
                Log.e(TAG, "Exception checking purchases: ${e.message}", e)
                if (cont.isActive) cont.resume(Unit)
            }
        }
    }

    fun updateFromServer(tier: String, expiresAt: Long?) {
        val subscriptionTier = when (tier) {
            "pepinillo_plus" -> SubscriptionTier.PEPINILLO_PLUS
            "everywhere_monthly" -> SubscriptionTier.EVERYWHERE_MONTHLY
            "everywhere_annual" -> SubscriptionTier.EVERYWHERE_ANNUAL
            "free", "" -> SubscriptionTier.FREE
            else -> {
                Log.w(TAG, "Unknown tier string from server: '$tier', defaulting to FREE")
                SubscriptionTier.FREE
            }
        }
        _subscriptionState.value = SubscriptionState(
            tier = subscriptionTier,
            expirationDate = expiresAt,
        )
    }

    private fun resolveActiveEntitlementId(customerInfo: com.revenuecat.purchases.CustomerInfo): String? {
        return SUPPORTED_ENTITLEMENT_IDS.firstOrNull { entitlementId ->
            customerInfo.entitlements[entitlementId]?.isActive == true
        }
    }

    private fun resolveActiveProductId(customerInfo: com.revenuecat.purchases.CustomerInfo): String? {
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
}
