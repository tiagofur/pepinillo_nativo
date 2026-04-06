package dev.creapolis.pepinillo.core.identity

import dev.creapolis.pepinillo.core.auth.AuthStore
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import javax.inject.Inject
import javax.inject.Singleton

enum class IdentityState {
    ANONYMOUS,
    REGISTERED,
    VERIFIED,
}

@Singleton
class IdentityManager @Inject constructor(
    private val authStore: AuthStore,
) {
    private val _identityState = MutableStateFlow(deriveState())
    val identityState: StateFlow<IdentityState> = _identityState.asStateFlow()

    fun refreshState() {
        _identityState.value = deriveState()
    }

    fun isAnonymous(): Boolean = _identityState.value == IdentityState.ANONYMOUS

    fun isAuthenticated(): Boolean = _identityState.value != IdentityState.ANONYMOUS

    private fun deriveState(): IdentityState {
        val hasToken = authStore.getAccessToken() != null
        if (!hasToken) return IdentityState.ANONYMOUS
        // AuthStore does not currently track email verification status separately.
        // When the backend provides that info we can distinguish REGISTERED vs VERIFIED.
        // For now, having tokens means at least REGISTERED.
        return IdentityState.REGISTERED
    }
}
