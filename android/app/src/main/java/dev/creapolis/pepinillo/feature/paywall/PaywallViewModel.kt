package dev.creapolis.pepinillo.feature.paywall

import android.app.Activity
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import dagger.hilt.android.lifecycle.HiltViewModel
import dev.creapolis.pepinillo.core.billing.ProductInfo
import dev.creapolis.pepinillo.core.billing.SubscriptionManager
import dev.creapolis.pepinillo.core.billing.SubscriptionState
import dev.creapolis.pepinillo.core.network.PepinilloApiClient
import dev.creapolis.pepinillo.core.network.VerifyReceiptRequest
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import javax.inject.Inject

data class PaywallUiState(
    val products: List<ProductInfo> = emptyList(),
    val selectedProductId: String? = null,
    val isPurchasing: Boolean = false,
    val isPro: Boolean = false,
    val error: String? = null,
)

@HiltViewModel
class PaywallViewModel @Inject constructor(
    private val subscriptionManager: SubscriptionManager,
    private val apiClient: PepinilloApiClient,
) : ViewModel() {

    private val _selectedProductId = MutableStateFlow<String?>(null)
    private val _isPurchasing = MutableStateFlow(false)
    private val _error = MutableStateFlow<String?>(null)

    val uiState: StateFlow<PaywallUiState> = combine(
        subscriptionManager.products,
        _selectedProductId,
        _isPurchasing,
        subscriptionManager.subscriptionState,
        _error,
    ) { products, selectedId, purchasing, subState, error ->
        PaywallUiState(
            products = products,
            selectedProductId = selectedId ?: products.find {
                it.productId.contains("annual")
            }?.productId,
            isPurchasing = purchasing,
            isPro = subState.isPro,
            error = error,
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
        _error.value = null

        viewModelScope.launch {
            subscriptionManager.launchPurchaseFlow(activity, product)
            // Observe subscription state changes to detect when purchase completes
            subscriptionManager.subscriptionState.collect { state ->
                if (state.isPro) {
                    _isPurchasing.value = false
                }
            }
        }
    }

    fun restorePurchases() {
        viewModelScope.launch {
            _isPurchasing.value = true
            _error.value = null
            subscriptionManager.checkExistingPurchases()
            _isPurchasing.value = false
            if (!subscriptionManager.subscriptionState.value.isPro) {
                _error.value = "No active subscription found"
            }
        }
    }

    fun clearError() {
        _error.value = null
    }
}
