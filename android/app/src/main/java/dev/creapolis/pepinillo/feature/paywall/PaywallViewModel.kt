package dev.creapolis.pepinillo.feature.paywall

import android.app.Activity
import android.util.Log
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import dagger.hilt.android.lifecycle.HiltViewModel
import dev.creapolis.pepinillo.core.auth.AuthStore
import dev.creapolis.pepinillo.core.billing.PaywallPolicy
import dev.creapolis.pepinillo.core.billing.PurchaseFlowResult
import dev.creapolis.pepinillo.core.billing.PurchaseVerificationTarget
import dev.creapolis.pepinillo.core.billing.RestoreFlowResult
import dev.creapolis.pepinillo.core.billing.SubscriptionManager
import dev.creapolis.pepinillo.core.network.NetworkResult
import dev.creapolis.pepinillo.core.network.PepinilloApiClient
import dev.creapolis.pepinillo.core.network.VerifyReceiptRequest
import dev.creapolis.pepinillo.data.repository.UserRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import javax.inject.Inject

private const val TAG = "PaywallViewModel"

data class PaywallUiState(
    val products: List<dev.creapolis.pepinillo.core.billing.ProductInfo> = emptyList(),
    val selectedProductId: String? = null,
    val isPurchasing: Boolean = false,
    val canSync: Boolean = false,
    val isPepinilloPlus: Boolean = false,
    val shouldAutoDismiss: Boolean = false,
    @field:androidx.annotation.StringRes val errorRes: Int? = null,
)

@HiltViewModel
class PaywallViewModel @Inject constructor(
    private val subscriptionManager: SubscriptionManager,
    private val apiClient: PepinilloApiClient,
    private val authStore: AuthStore,
    private val userRepository: UserRepository,
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
        val resolvedSelected = selectedId ?: products.find {
            it.productId.contains("annual")
        }?.productId
        PaywallUiState(
            products = products,
            selectedProductId = resolvedSelected,
            isPurchasing = purchasing,
            canSync = subState.canSync,
            isPepinilloPlus = subState.isPepinilloPlus,
            shouldAutoDismiss = PaywallPolicy.shouldAutoDismiss(subState, resolvedSelected),
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
        if (_isPurchasing.value) return
        val selectedId = uiState.value.selectedProductId ?: return
        val product = uiState.value.products.find { it.productId == selectedId } ?: return

        _isPurchasing.value = true
        _errorRes.value = null

        viewModelScope.launch {
            try {
                when (val result = subscriptionManager.launchPurchaseFlow(activity, product)) {
                    is PurchaseFlowResult.Success -> {
                        verifyWithServerIfNeeded(result.verification)
                    }
                    is PurchaseFlowResult.Cancelled -> { /* expected */ }
                    is PurchaseFlowResult.Pending -> {
                        _errorRes.value = dev.creapolis.pepinillo.R.string.paywall_purchase_pending
                    }
                    is PurchaseFlowResult.Failed -> {
                        _errorRes.value = dev.creapolis.pepinillo.R.string.paywall_purchase_failed
                        Log.w(TAG, "Purchase failed: ${result.message}")
                    }
                }
            } finally {
                _isPurchasing.value = false
            }
        }
    }

    fun restorePurchases() {
        if (_isPurchasing.value) return
        _isPurchasing.value = true
        _errorRes.value = null

        viewModelScope.launch {
            try {
                when (val result = subscriptionManager.restorePurchases()) {
                    is RestoreFlowResult.Success -> {
                        if (result.state.hasLocalPremium) {
                            verifyWithServerIfNeeded(result.verification)
                        } else {
                            _errorRes.value = dev.creapolis.pepinillo.R.string.paywall_no_subscription
                        }
                    }
                    is RestoreFlowResult.Failed -> {
                        _errorRes.value = dev.creapolis.pepinillo.R.string.paywall_restore_failed
                        Log.w(TAG, "Restore failed: ${result.message}")
                    }
                }
            } finally {
                _isPurchasing.value = false
            }
        }
    }

    fun clearError() {
        _errorRes.value = null
    }

    private suspend fun verifyWithServerIfNeeded(verification: PurchaseVerificationTarget?) {
        if (authStore.getAccessToken() == null) return

        if (verification == null) {
            syncSubscriptionFromProfile()
            return
        }

        when (
            val result = apiClient.verifyReceipt(
                VerifyReceiptRequest(
                    productId = verification.productId,
                    purchaseToken = verification.purchaseToken,
                ),
            )
        ) {
            is NetworkResult.Success -> {
                subscriptionManager.updateFromServer(
                    result.data.subscriptionTier,
                    result.data.subscriptionExpiresAt,
                )
                userRepository.fetchAndCacheProfile()
            }
            is NetworkResult.Error -> {
                Log.w(TAG, "Server verify failed: ${result.code} ${result.message}")
                syncSubscriptionFromProfile()
            }
            is NetworkResult.NetworkError -> {
                Log.w(TAG, "Server verify network error", result.exception)
            }
        }
    }

    /** Restore has no purchase token in RC 8.x — fall back to server profile tier. */
    private suspend fun syncSubscriptionFromProfile() {
        userRepository.fetchAndCacheProfile().onSuccess { user ->
            subscriptionManager.updateFromServer(
                user.subscriptionTier,
                parseSubscriptionExpiresAt(user.subscriptionExpiresAt),
            )
        }
    }

    private fun parseSubscriptionExpiresAt(raw: String?): Long? {
        if (raw.isNullOrBlank()) return null
        raw.toLongOrNull()?.let { return it }
        return runCatching { java.time.Instant.parse(raw).toEpochMilli() }.getOrNull()
    }
}