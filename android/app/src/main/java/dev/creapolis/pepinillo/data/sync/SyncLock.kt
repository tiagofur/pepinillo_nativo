package dev.creapolis.pepinillo.data.sync

import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Process-wide mutex serializing sync engine work so concurrent callers
 * (SyncWorker, WebSocket push, MainActivity, AuthViewModel) cannot race
 * merge/markSynced operations.
 */
@Singleton
class SyncLock @Inject constructor() {
    private val mutex = Mutex()

    suspend fun <T> withLock(block: suspend () -> T): T = mutex.withLock { block() }
}