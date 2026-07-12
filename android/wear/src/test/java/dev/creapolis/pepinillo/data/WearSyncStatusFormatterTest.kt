package dev.creapolis.pepinillo.data

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.util.Locale

/**
 * S7 (#393): sync status labels are driven by localized string resources.
 */
class WearSyncStatusFormatterTest {

    private val strings = SyncStatusStrings(
        waitingFirst = "Waiting for first sync",
        disconnectedLastFormat = "No connection · last %s",
        staleFormat = "Sync delayed · %s",
        okFormat = "Synced %s",
    )

    @Test
    fun `connected without sync shows waiting label`() {
        val status = WearSyncStatusFormatter.format(
            strings = strings,
            lastSyncAtMillis = null,
            isConnected = true,
            nowMillis = 10_000L,
            locale = Locale.US,
        )

        assertEquals("Waiting for first sync", status.label)
        assertFalse(status.isStale)
    }

    @Test
    fun `connected recent sync is not stale`() {
        val status = WearSyncStatusFormatter.format(
            strings = strings,
            lastSyncAtMillis = 100_000L,
            isConnected = true,
            nowMillis = 150_000L,
            locale = Locale.US,
        )

        assertTrue(status.label!!.startsWith("Synced "))
        assertFalse(status.isStale)
    }

    @Test
    fun `connected old sync is marked stale`() {
        val status = WearSyncStatusFormatter.format(
            strings = strings,
            lastSyncAtMillis = 100_000L,
            isConnected = true,
            nowMillis = 300_001L,
            locale = Locale.US,
        )

        assertTrue(status.label!!.startsWith("Sync delayed"))
        assertTrue(status.isStale)
    }

    @Test
    fun `disconnected shows last known sync`() {
        val status = WearSyncStatusFormatter.format(
            strings = strings,
            lastSyncAtMillis = 100_000L,
            isConnected = false,
            nowMillis = 110_000L,
            locale = Locale.US,
        )

        assertTrue(status.label!!.startsWith("No connection · last "))
        assertTrue(status.isStale)
    }
}