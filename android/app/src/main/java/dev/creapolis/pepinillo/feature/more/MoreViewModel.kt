package dev.creapolis.pepinillo.feature.more

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import dagger.hilt.android.lifecycle.HiltViewModel
import dev.creapolis.pepinillo.core.auth.AuthStore
import dev.creapolis.pepinillo.core.billing.FeatureGate
import dev.creapolis.pepinillo.core.billing.SubscriptionManager
import dev.creapolis.pepinillo.core.billing.SubscriptionState
import dev.creapolis.pepinillo.core.billing.SubscriptionTier
import dev.creapolis.pepinillo.core.network.PepinilloApiClient
import dev.creapolis.pepinillo.data.local.entity.UserEntity
import dev.creapolis.pepinillo.data.repository.UserRepository
import dev.creapolis.pepinillo.data.sync.SyncWebSocketClient
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import javax.inject.Inject

data class MoreUiState(
    val isLoggedIn: Boolean = false,
    val user: UserEntity? = null,
    val isPro: Boolean = false,
    val isEverywhere: Boolean = false,
    val isLoading: Boolean = false,
    val error: String? = null
)

@HiltViewModel
class MoreViewModel @Inject constructor(
    private val authStore: AuthStore,
    private val userRepository: UserRepository,
    private val featureGate: FeatureGate,
    private val apiClient: PepinilloApiClient,
    private val syncWebSocketClient: SyncWebSocketClient,
    private val subscriptionManager: SubscriptionManager,
) : ViewModel() {

    val uiState: StateFlow<MoreUiState> = combine(
        authStore.isLoggedIn,
        userRepository.observeCachedUser(),
        featureGate.subscriptionState
    ) { isLoggedIn, user, subState ->
        MoreUiState(
            isLoggedIn = isLoggedIn,
            user = user,
            isPro = subState.hasLocalPremium,
            isEverywhere = subState.canSync
        )
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), MoreUiState())

    fun logout() {
        viewModelScope.launch {
            syncWebSocketClient.disconnect()
            val refreshToken = authStore.getRefreshToken()
            apiClient.logout(refreshToken)
            subscriptionManager.logOut()
            userRepository.clearCache()
            authStore.clearAll()
        }
    }
}
