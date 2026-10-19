package dev.creapolis.pepinillo.data

import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.withTimeoutOrNull

/**
 * Reconciliation for fire-and-forget timer commands (E2: phantom watch session).
 *
 * [WearMessageSender] succeeding only means GMS accepted the message for delivery.
 * If the phone never receives or processes it, the watch's optimistic Running/Paused
 * state keeps ticking with no phone session behind it. This watchdog sends a timer
 * command and then waits for the phone to confirm it with an authoritative timer
 * DataItem — any PATH_TIMER application bumps [WearDataStore.remoteTimerRevisions].
 *
 * Semantics:
 *  - Delivery failed synchronously (no connected nodes / GMS error): `sendCommand`
 *    already queued the command offline, so only the optimistic state is rolled back.
 *  - Delivered but unconfirmed within [DEFAULT_CONFIRMATION_TIMEOUT_MS]: the phone
 *    never processed the command. Roll the optimistic state back and re-deliver once;
 *    if that second attempt cannot be delivered either, `sendCommand` queues it for
 *    reconnect (queue coalescing keeps it free of duplicates).
 *  - Superseded (the local state no longer equals the optimistic state we applied —
 *    a newer user action or a remote DataItem overwrote it): stand down without
 *    reverting, so the watchdog never fights a newer action or the phone's truth.
 */
internal object WearCommandWatchdog {
    /** How long to wait for the confirming timer DataItem before reverting (~5s). */
    const val DEFAULT_CONFIRMATION_TIMEOUT_MS = 5_000L

    suspend fun runCommand(
        remoteRevisions: StateFlow<Long>,
        timeoutMs: Long = DEFAULT_CONFIRMATION_TIMEOUT_MS,
        isStillOptimistic: () -> Boolean,
        onRevert: () -> Unit,
        action: suspend () -> Boolean,
    ) {
        val revisionBefore = remoteRevisions.value
        val delivered = runCatching { action() }.getOrDefault(false)
        if (!delivered) {
            if (isStillOptimistic()) onRevert()
            return
        }

        val confirmed = withTimeoutOrNull(timeoutMs) {
            remoteRevisions.first { it > revisionBefore }
        } != null
        if (confirmed || !isStillOptimistic()) return

        onRevert()
        runCatching { action() }
    }
}
