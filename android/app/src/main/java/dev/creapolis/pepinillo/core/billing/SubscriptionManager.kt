package dev.creapolis.pepinillo.core.billing

import android.app.Activity
import android.content.Context
import android.util.Log
import com.revenuecat.purchases.CustomerInfo
import com.revenuecat.purchases.Package
import com.revenuecat.purchases.PurchaseParams
import com.revenuecat.purchases.Purchases
import com.revenuecat.purchases.PurchasesConfiguration
import com.revenuecat.purchases.PurchasesErrorCode
import com.revenuecat.purchases.getCustomerInfoWith
import com.revenuecat.purchases.getOfferingsWith
import com.revenuecat.purchases.interfaces.UpdatedCustomerInfoListener
import com.revenuecat.purchases.logInWith
import com.revenuecat.purchases.logOutWith
import com.revenuecat.purchases.purchaseWith
import com.revenuecat.purchases.restorePurchasesWith
import dagger.hilt.android.qualifiers.ApplicationContext
import dev.creapolis.pepinillo.BuildConfig
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.suspendCancellableCoroutine
import javax.inject.Inject
import javax.inject.Singleton
import kotlin.coroutines.resume

private const val TAG = "SubscriptionManager"
private const val REVENUECAT_API_KEY = BuildConfig.REVENUECAT_API_KEY

/** Result of a purchase attempt — distinguishes user cancel from real failure. */
enum class PurchaseResult { Success, Cancelled, Failed, Pending }

data class ProductInfo(
    val productId: String,
    val title: String,
    val description: String,
    val formattedPrice: String,
    val priceMicros: Long,
    val billingPeriod: String?,
    val `package`: Package,
)

sealed class PurchaseFlowResult {
    data object Cancelled : PurchaseFlowResult()
    data object Pending : PurchaseFlowResult()
    data class Failed(val message: String?) : PurchaseFlowResult()
    data class Success(
        val state: SubscriptionState,
        val verification: PurchaseVerificationTarget?,
    ) : PurchaseFlowResult()
}

sealed class RestoreFlowResult {
    data class Failed(val message: String?) : RestoreFlowResult()
    data class Success(
        val state: SubscriptionState,
        val verification: PurchaseVerificationTarget?,
    ) : RestoreFlowResult()
}

@Singleton
class SubscriptionManager @Inject constructor(
    @ApplicationContext private val context: Context,
) {

    private val _subscriptionState = MutableStateFlow(SubscriptionState())
    val subscriptionState: StateFlow<SubscriptionState> = _subscriptionState.asStateFlow()

    private val _products = MutableStateFlow<List<ProductInfo>>(emptyList())
    val products: StateFlow<List<ProductInfo>> = _products.asStateFlow()

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
    private val operationMutex = Mutex()
    private var isInitialized = false


    init {
        initializeRevenueCat()
    }

    private fun initializeRevenueCat() {
        if (isInitialized) return
        try {
            if (!Purchases.isConfigured) {
                Purchases.configure(PurchasesConfiguration.Builder(context, REVENUECAT_API_KEY).build())
                Log.d(TAG, "RevenueCat initialized in Manager")
            }
            Purchases.sharedInstance.updatedCustomerInfoListener =
                UpdatedCustomerInfoListener { customerInfo ->
                    applyCustomerInfo(customerInfo)
                }
            isInitialized = true
            scope.launch { refreshCustomerInfo() }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to initialize RevenueCat: ${e.message}", e)
        }
    }

    suspend fun connect() {
        if (!isInitialized) initializeRevenueCat()
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
                                    priceMicros = product.price.amountMicros,
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

    suspend fun launchPurchaseFlow(activity: Activity, product: ProductInfo): PurchaseFlowResult = operationMutex.withLock {
        if (!isInitialized) connect()

        return suspendCancellableCoroutine { cont ->
            Purchases.sharedInstance.purchaseWith(
                purchaseParams = PurchaseParams.Builder(activity, product.`package`).build(),
                onSuccess = { storeTransaction, customerInfo ->
                    Log.d(TAG, "Purchase successful for ${product.productId}")
                    val state = applyCustomerInfo(customerInfo)
                    val verification = purchaseVerificationTarget(
                        customerInfo = customerInfo,
                        productId = product.productId,
                        storeTransaction = storeTransaction,
                    )
                    if (cont.isActive) {
                        cont.resume(
                            if (state.hasLocalPremium) {
                                PurchaseFlowResult.Success(state, verification)
                            } else {
                                PurchaseFlowResult.Failed("Purchase completed but entitlement not active")
                            },
                        )
                    }
                },
                onError = { error, userCancelled ->
                    Log.e(TAG, "Purchase failed: ${error.code} - ${error.message}")
                    if (cont.isActive) {
                        cont.resume(
                            when {
                                userCancelled -> PurchaseFlowResult.Cancelled
                                error.code == PurchasesErrorCode.PaymentPendingError -> PurchaseFlowResult.Pending
                                else -> PurchaseFlowResult.Failed(error.message)
                            },
                        )
                    }
                },
            )
        }
    }

    suspend fun restorePurchases(): RestoreFlowResult = operationMutex.withLock {
        if (!isInitialized) connect()

        return suspendCancellableCoroutine { cont ->
            Purchases.sharedInstance.restorePurchasesWith(
                onError = { error ->
                    Log.e(TAG, "Restore failed: ${error.message}")
                    if (cont.isActive) cont.resume(RestoreFlowResult.Failed(error.message))
                },
                onSuccess = { customerInfo ->
                    Log.d(TAG, "Restore completed")
                    val state = applyCustomerInfo(customerInfo)
                    val verification = purchaseVerificationTarget(
                        customerInfo = customerInfo,
                        productId = state.activeProductId,
                    )
                    if (cont.isActive) {
                        cont.resume(RestoreFlowResult.Success(state, verification))
                    }
                },
            )
        }
    }

    suspend fun logIn(appUserId: String) {
        if (!isInitialized) connect()
        if (appUserId.isBlank()) return

        suspendCancellableCoroutine { cont ->
            Purchases.sharedInstance.logInWith(
                appUserID = appUserId,
                onError = { error ->
                    Log.e(TAG, "RevenueCat logIn failed: ${error.message}")
                    if (cont.isActive) cont.resume(Unit)
                },
                onSuccess = { customerInfo, _ ->
                    applyCustomerInfo(customerInfo)
                    if (cont.isActive) cont.resume(Unit)
                },
            )
        }
    }

    suspend fun logOut() {
        if (!isInitialized) return

        suspendCancellableCoroutine { cont ->
            Purchases.sharedInstance.logOutWith(
                onError = { error ->
                    Log.e(TAG, "RevenueCat logOut failed: ${error.message}")
                    if (cont.isActive) cont.resume(Unit)
                },
                onSuccess = { customerInfo ->
                    applyCustomerInfo(customerInfo)
                    if (cont.isActive) cont.resume(Unit)
                },
            )
        }
    }

    suspend fun refreshCustomerInfo() {
        if (!isInitialized) connect()

        suspendCancellableCoroutine { cont ->
            Purchases.sharedInstance.getCustomerInfoWith(
                onError = { error ->
                    Log.e(TAG, "Failed to get customer info: ${error.message}")
                    if (cont.isActive) cont.resume(Unit)
                },
                onSuccess = { customerInfo ->
                    applyCustomerInfo(customerInfo)
                    if (cont.isActive) cont.resume(Unit)
                },
            )
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

    private fun applyCustomerInfo(customerInfo: CustomerInfo): SubscriptionState {
        val state = subscriptionStateFromCustomerInfo(customerInfo)
        _subscriptionState.value = state
        return state
    }
}