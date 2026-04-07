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
private const val ENTITLEMENT_ID = "premium"

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
            Purchases.configure(PurchasesConfiguration.Builder(context, REVENUECAT_API_KEY).build())
            Log.d(TAG, "RevenueCat initialized")
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

                        // Iterate through all offerings and their packages
                        offerings.all.values.forEach { offering ->
                            offering.availablePackages.forEach { pkg ->
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
                        }

                        _products.value = allProducts
                        Log.d(TAG, "Loaded ${allProducts.size} products")
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
                        val entitlement = customerInfo.entitlements[ENTITLEMENT_ID]
                        if (entitlement?.isActive == true) {
                            // Find which product is active
                            val activeProductId = customerInfo.activeSubscriptions.firstOrNull { productId ->
                                productId in PepinilloProducts.ALL_IDS
                            } ?: customerInfo.nonSubscriptionTransactions.map { it.productIdentifier }.firstOrNull { productId ->
                                productId in PepinilloProducts.ALL_IDS
                            }
                            if (activeProductId != null) {
                                val tier = PepinilloProducts.tierForProduct(activeProductId)
                                _subscriptionState.value = SubscriptionState(
                                    tier = tier,
                                    activeProductId = activeProductId,
                                )
                                Log.d(TAG, "Subscription active: $tier ($activeProductId)")
                            }
                        } else {
                            _subscriptionState.value = SubscriptionState()
                            Log.d(TAG, "No active premium entitlement")
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
            "pro_monthly" -> SubscriptionTier.PRO_MONTHLY
            "pro_yearly" -> SubscriptionTier.PRO_YEARLY
            "lifetime" -> SubscriptionTier.LIFETIME
            else -> SubscriptionTier.FREE
        }
        _subscriptionState.value = SubscriptionState(
            tier = subscriptionTier,
            expirationDate = expiresAt,
        )
    }
}
