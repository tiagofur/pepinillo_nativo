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

    /** True only when there is a token AND the email has been verified. */
    fun isEmailVerified(): Boolean = _identityState.value == IdentityState.VERIFIED

    private fun deriveState(): IdentityState {
        val hasToken = authStore.getAccessToken() != null
        if (!hasToken) return IdentityState.ANONYMOUS
        // Token exists — distinguish unverified (REGISTERED) from verified (VERIFIED).
        // This lets cold-start and SyncLifecycleObserver gate unverified sessions to the
        // verification screen instead of treating them as fully authenticated.
        return if (authStore.isEmailVerified()) IdentityState.VERIFIED else IdentityState.REGISTERED
    }
}
