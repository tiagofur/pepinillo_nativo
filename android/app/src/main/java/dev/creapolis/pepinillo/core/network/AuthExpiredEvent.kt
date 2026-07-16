package dev.creapolis.pepinillo.core.network

import kotlinx.coroutines.channels.BufferOverflow
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.asSharedFlow
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Global one-shot event bus for "session expired" signals.
 *
 * Emitted by [NetworkModule] when a token refresh is rejected (401/403) and the session
 * is cleared mid-flight. Collected by the UI layer (MainActivity) to force-navigate to
 * the login screen and show a re-auth snackbar — previously the user was left on a stale
 * "logged-in" screen with silent sync failures.
 */
@Singleton
class AuthExpiredEvent @Inject constructor() {

    private val _events = MutableSharedFlow<Unit>(
        replay = 0,
        extraBufferCapacity = 1,
        onBufferOverflow = BufferOverflow.DROP_OLDEST,
    )
    val events: SharedFlow<Unit> = _events.asSharedFlow()

    fun emit() {
        _events.tryEmit(Unit)
    }
}
