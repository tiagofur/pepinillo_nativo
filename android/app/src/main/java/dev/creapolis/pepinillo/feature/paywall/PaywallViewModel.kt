package dev.creapolis.pepinillo.feature.paywall

import android.app.Activity
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import dagger.hilt.android.lifecycle.HiltViewModel
import dev.creapolis.pepinillo.core.billing.ProductInfo
import dev.creapolis.pepinillo.core.billing.PurchaseResult
import dev.creapolis.pepinillo.core.billing.SubscriptionManager
import dev.creapolis.pepinillo.core.billing.SubscriptionState
import dev.creapolis.pepinillo.core.network.PepinilloApiClient
import dev.creapolis.pepinillo.core.network.VerifyReceiptRequest
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import javax.inject.Inject

data class PaywallUiState(
    val products: List<ProductInfo> = emptyList(),
    val selectedProductId: String? = null,
    val isPurchasing: Boolean = false,
    val isPro: Boolean = false,
    @field:androidx.annotation.StringRes val errorRes: Int? = null,
)

@HiltViewModel
class PaywallViewModel @Inject constructor(
    private val subscriptionManager: SubscriptionManager,
    private val apiClient: PepinilloApiClient,
) : ViewModel() {

    private val _selectedProductId = MutableStateFlow<String?>(null)
    private val _isPurchasing = MutableStateFlow(false)
    private val _errorRes = MutableStateFlow<Int?>(null)

    val uiState: StateFlow<PaywallUiState> = combine(
        subscriptionManager.products,
        _selectedProductId,
        _isPurchasing,
        subscriptionManager.subscriptionState,
        _errorRes,
    ) { products, selectedId, purchasing, subState, errorRes ->
        PaywallUiState(
            products = products,
            selectedProductId = selectedId ?: products.find {
                it.productId.contains("annual")
            }?.productId,
            isPurchasing = purchasing,
            isPro = subState.hasLocalPremium,
            errorRes = errorRes,
        )
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), PaywallUiState())

    init {
        viewModelScope.launch {
            subscriptionManager.connect()
            subscriptionManager.queryProducts()
        }
    }

    fun selectProduct(productId: String) {
        _selectedProductId.value = productId
    }

    fun purchase(activity: Activity) {
        val selectedId = uiState.value.selectedProductId ?: return
        val product = uiState.value.products.find { it.productId == selectedId } ?: return

        _isPurchasing.value = true
        _errorRes.value = null

        viewModelScope.launch {
            val result = subscriptionManager.launchPurchaseFlow(activity, product)
            _isPurchasing.value = false
            when (result) {
                PurchaseResult.Success -> {
                    // Wait briefly for entitlement to propagate, then stop collecting.
                    subscriptionManager.subscriptionState.first { it.hasLocalPremium }
                }
                PurchaseResult.Cancelled -> { /* expected — do nothing, no error message */ }
                PurchaseResult.Failed -> {
                    _errorRes.value = dev.creapolis.pepinillo.R.string.paywall_purchase_failed
                }
            }
        }
    }

    fun restorePurchases() {
        viewModelScope.launch {
            _isPurchasing.value = true
            _errorRes.value = null
            subscriptionManager.checkExistingPurchases()
            _isPurchasing.value = false
            if (!subscriptionManager.subscriptionState.value.hasLocalPremium) {
                _errorRes.value = dev.creapolis.pepinillo.R.string.paywall_no_subscription
            }
        }
    }

    fun clearError() {
        _errorRes.value = null
    }
}
