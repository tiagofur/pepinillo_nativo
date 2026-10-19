package dev.creapolis.pepinillo.data

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.test.advanceTimeBy
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * E2: a Wear timer command accepted by GMS is not confirmed until the phone pushes
 * an authoritative timer DataItem (which bumps [WearDataStore.remoteTimerRevisions]).
 * These tests pin the watchdog contract: revert + one re-delivery when unconfirmed,
 * stand down when confirmed or superseded, immediate revert when undeliverable.
 */
@OptIn(kotlinx.coroutines.ExperimentalCoroutinesApi::class)
class WearCommandWatchdogTest {

    @Test
    fun `delivered command without confirmation reverts and re-delivers once`() = runTest {
        val revisions = MutableStateFlow(3L)
        var sends = 0
        var reverts = 0

        launch {
            WearCommandWatchdog.runCommand(
                remoteRevisions = revisions,
                timeoutMs = 5_000L,
                isStillOptimistic = { true },
                onRevert = { reverts++ },
                action = { sends++; true },
            )
        }
        runCurrent()

        // First delivery happened; the watchdog is now waiting for a revision bump.
        assertEquals(1, sends)
        assertEquals(0, reverts)

        advanceTimeBy(5_001L)

        // No confirmation: optimistic state reverted, exactly one re-delivery attempted.
        assertEquals(2, sends)
        assertEquals(1, reverts)
    }

    @Test
    fun `confirmation within the timeout stands down without revert`() = runTest {
        val revisions = MutableStateFlow(7L)
        var sends = 0
        var reverts = 0

        launch {
            WearCommandWatchdog.runCommand(
                remoteRevisions = revisions,
                timeoutMs = 5_000L,
                isStillOptimistic = { true },
                onRevert = { reverts++ },
                action = { sends++; true },
            )
        }
        runCurrent()

        // The phone pushes the confirming timer DataItem (revision 7 -> 8).
        revisions.value = 8L
        advanceUntilIdle()

        assertEquals(1, sends)
        assertEquals(0, reverts)
    }

    @Test
    fun `revision bump before the send does not confirm the command`() = runTest {
        val revisions = MutableStateFlow(3L)
        var sends = 0
        var reverts = 0

        launch {
            WearCommandWatchdog.runCommand(
                remoteRevisions = revisions,
                timeoutMs = 5_000L,
                isStillOptimistic = { true },
                onRevert = { reverts++ },
                action = { sends++; true },
            )
        }
        // The counter sits at 3L the whole time: no DataItem ever arrives after the send.
        advanceUntilIdle()

        assertEquals(2, sends)
        assertEquals(1, reverts)
    }

    @Test
    fun `undeliverable command reverts immediately without waiting or re-delivering`() = runTest {
        val revisions = MutableStateFlow(0L)
        var sends = 0
        var reverts = 0

        launch {
            WearCommandWatchdog.runCommand(
                remoteRevisions = revisions,
                timeoutMs = 5_000L,
                isStillOptimistic = { true },
                onRevert = { reverts++ },
                action = { sends++; false },
            )
        }
        runCurrent()

        // GMS could not hand the message to any node; sendCommand already queued it
        // offline, so the watchdog only reverts — no wait, no re-delivery.
        assertEquals(1, sends)
        assertEquals(1, reverts)

        advanceTimeBy(30_000L)
        assertEquals(1, sends)
        assertEquals(1, reverts)
    }

    @Test
    fun `exception during send is treated as undeliverable`() = runTest {
        val revisions = MutableStateFlow(0L)
        var sends = 0
        var reverts = 0

        launch {
            WearCommandWatchdog.runCommand(
                remoteRevisions = revisions,
                timeoutMs = 5_000L,
                isStillOptimistic = { true },
                onRevert = { reverts++ },
                action = { sends++; error("gms down") },
            )
        }
        runCurrent()

        assertEquals(1, sends)
        assertEquals(1, reverts)
    }

    @Test
    fun `superseded optimistic state is left untouched`() = runTest {
        val revisions = MutableStateFlow(0L)
        var sends = 0
        var reverts = 0

        launch {
            WearCommandWatchdog.runCommand(
                remoteRevisions = revisions,
                timeoutMs = 5_000L,
                isStillOptimistic = { false },
                onRevert = { reverts++ },
                action = { sends++; true },
            )
        }
        advanceUntilIdle()

        // A newer action (or remote DataItem) replaced the optimistic state: no revert,
        // no re-delivery that could fight the newer state.
        assertEquals(1, sends)
        assertEquals(0, reverts)
    }
}
