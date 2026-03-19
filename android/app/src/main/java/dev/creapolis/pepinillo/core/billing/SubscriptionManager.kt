package dev.creapolis.pepinillo.core.billing

import android.app.Activity
import android.content.Context
import android.util.Log
import com.android.billingclient.api.AcknowledgePurchaseParams
import com.android.billingclient.api.BillingClient
import com.android.billingclient.api.BillingClientStateListener
import com.android.billingclient.api.BillingFlowParams
import com.android.billingclient.api.BillingResult
import com.android.billingclient.api.ProductDetails
import com.android.billingclient.api.Purchase
import com.android.billingclient.api.PurchasesUpdatedListener
import com.android.billingclient.api.QueryProductDetailsParams
import com.android.billingclient.api.QueryPurchasesParams
import com.android.billingclient.api.queryProductDetails
import com.android.billingclient.api.queryPurchasesAsync
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.suspendCancellableCoroutine
import javax.inject.Inject
import javax.inject.Singleton
import kotlin.coroutines.resume

private const val TAG = "SubscriptionManager"

data class ProductInfo(
    val productId: String,
    val title: String,
    val description: String,
    val formattedPrice: String,
    val priceMicros: Long,
    val billingPeriod: String?,
    val productDetails: ProductDetails,
)

@Singleton
class SubscriptionManager @Inject constructor(
    @ApplicationContext private val context: Context,
) : PurchasesUpdatedListener {

    private val _subscriptionState = MutableStateFlow(SubscriptionState())
    val subscriptionState: StateFlow<SubscriptionState> = _subscriptionState.asStateFlow()

    private val _products = MutableStateFlow<List<ProductInfo>>(emptyList())
    val products: StateFlow<List<ProductInfo>> = _products.asStateFlow()

    private var billingClient: BillingClient = BillingClient.newBuilder(context)
        .setListener(this)
        .enablePendingPurchases()
        .build()

    private var isConnected = false

    suspend fun connect() {
        if (isConnected) return
        suspendCancellableCoroutine { cont ->
            billingClient.startConnection(object : BillingClientStateListener {
                override fun onBillingSetupFinished(result: BillingResult) {
                    isConnected = result.responseCode == BillingClient.BillingResponseCode.OK
                    if (isConnected) {
                        Log.d(TAG, "Billing connected")
                    } else {
                        Log.e(TAG, "Billing setup failed: ${result.debugMessage}")
                    }
                    if (cont.isActive) cont.resume(Unit)
                }

                override fun onBillingServiceDisconnected() {
                    isConnected = false
                    Log.w(TAG, "Billing disconnected")
                }
            })
        }
    }

    suspend fun queryProducts() {
        if (!isConnected) connect()

        val subParams = PepinilloProducts.SUBSCRIPTION_IDS.map {
            QueryProductDetailsParams.Product.newBuilder()
                .setProductId(it)
                .setProductType(BillingClient.ProductType.SUBS)
                .build()
        }
        val inappParams = PepinilloProducts.INAPP_IDS.map {
            QueryProductDetailsParams.Product.newBuilder()
                .setProductId(it)
                .setProductType(BillingClient.ProductType.INAPP)
                .build()
        }

        val allProducts = mutableListOf<ProductInfo>()

        // Query subscriptions
        if (subParams.isNotEmpty()) {
            val subResult = billingClient.queryProductDetails(
                QueryProductDetailsParams.newBuilder().setProductList(subParams).build(),
            )
            subResult.productDetailsList?.forEach { details ->
                val offer = details.subscriptionOfferDetails?.firstOrNull()
                val pricingPhase = offer?.pricingPhases?.pricingPhaseList?.lastOrNull()
                allProducts.add(
                    ProductInfo(
                        productId = details.productId,
                        title = details.title,
                        description = details.description,
                        formattedPrice = pricingPhase?.formattedPrice ?: "",
                        priceMicros = pricingPhase?.priceAmountMicros ?: 0,
                        billingPeriod = pricingPhase?.billingPeriod,
                        productDetails = details,
                    ),
                )
            }
        }

        // Query in-app (lifetime)
        if (inappParams.isNotEmpty()) {
            val inappResult = billingClient.queryProductDetails(
                QueryProductDetailsParams.newBuilder().setProductList(inappParams).build(),
            )
            inappResult.productDetailsList?.forEach { details ->
                val oneTime = details.oneTimePurchaseOfferDetails
                allProducts.add(
                    ProductInfo(
                        productId = details.productId,
                        title = details.title,
                        description = details.description,
                        formattedPrice = oneTime?.formattedPrice ?: "",
                        priceMicros = oneTime?.priceAmountMicros ?: 0,
                        billingPeriod = null,
                        productDetails = details,
                    ),
                )
            }
        }

        _products.value = allProducts
        Log.d(TAG, "Loaded ${allProducts.size} products")
    }

    fun launchPurchaseFlow(activity: Activity, product: ProductInfo): BillingResult {
        val paramsBuilder = BillingFlowParams.ProductDetailsParams.newBuilder()
            .setProductDetails(product.productDetails)

        // For subscriptions, we need to set the offer token
        val offer = product.productDetails.subscriptionOfferDetails?.firstOrNull()
        if (offer != null) {
            paramsBuilder.setOfferToken(offer.offerToken)
        }

        val flowParams = BillingFlowParams.newBuilder()
            .setProductDetailsParamsList(listOf(paramsBuilder.build()))
            .build()

        return billingClient.launchBillingFlow(activity, flowParams)
    }

    override fun onPurchasesUpdated(result: BillingResult, purchases: List<Purchase>?) {
        when (result.responseCode) {
            BillingClient.BillingResponseCode.OK -> {
                purchases?.forEach { purchase ->
                    if (purchase.purchaseState == Purchase.PurchaseState.PURCHASED) {
                        acknowledgePurchase(purchase)
                        updateStateFromPurchase(purchase)
                    }
                }
            }
            BillingClient.BillingResponseCode.USER_CANCELED -> {
                Log.d(TAG, "User canceled purchase")
            }
            else -> {
                Log.e(TAG, "Purchase error: ${result.responseCode} - ${result.debugMessage}")
            }
        }
    }

    private fun acknowledgePurchase(purchase: Purchase) {
        if (purchase.isAcknowledged) return
        val params = AcknowledgePurchaseParams.newBuilder()
            .setPurchaseToken(purchase.purchaseToken)
            .build()
        billingClient.acknowledgePurchase(params) { result ->
            if (result.responseCode == BillingClient.BillingResponseCode.OK) {
                Log.d(TAG, "Purchase acknowledged")
            } else {
                Log.e(TAG, "Acknowledge failed: ${result.debugMessage}")
            }
        }
    }

    suspend fun checkExistingPurchases() {
        if (!isConnected) connect()

        // Check subscriptions
        val subResult = billingClient.queryPurchasesAsync(
            QueryPurchasesParams.newBuilder()
                .setProductType(BillingClient.ProductType.SUBS)
                .build(),
        )
        val activeSub = subResult.purchasesList.firstOrNull {
            it.purchaseState == Purchase.PurchaseState.PURCHASED
        }

        if (activeSub != null) {
            updateStateFromPurchase(activeSub)
            return
        }

        // Check in-app purchases (lifetime)
        val inappResult = billingClient.queryPurchasesAsync(
            QueryPurchasesParams.newBuilder()
                .setProductType(BillingClient.ProductType.INAPP)
                .build(),
        )
        val lifetimePurchase = inappResult.purchasesList.firstOrNull { purchase ->
            purchase.purchaseState == Purchase.PurchaseState.PURCHASED &&
                purchase.products.any { p -> p == PepinilloProducts.LIFETIME }
        }

        if (lifetimePurchase != null) {
            updateStateFromPurchase(lifetimePurchase)
        } else {
            _subscriptionState.value = SubscriptionState()
        }
    }

    private fun updateStateFromPurchase(purchase: Purchase) {
        val productId = purchase.products.firstOrNull() ?: return
        val tier = PepinilloProducts.tierForProduct(productId)
        _subscriptionState.value = SubscriptionState(
            tier = tier,
            activeProductId = productId,
        )
        Log.d(TAG, "Subscription updated: $tier ($productId)")
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
