package dev.creapolis.pepinillo.data

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.util.Locale

class WearSyncStatusFormatterTest {

    @Test
    fun `connected without sync shows waiting label`() {
        val status = WearSyncStatusFormatter.format(
            lastSyncAtMillis = null,
            isConnected = true,
            nowMillis = 10_000L,
            locale = Locale.US,
        )

        assertEquals("Esperando primera sync", status.label)
        assertFalse(status.isStale)
    }

    @Test
    fun `connected recent sync is not stale`() {
        val status = WearSyncStatusFormatter.format(
            lastSyncAtMillis = 100_000L,
            isConnected = true,
            nowMillis = 150_000L,
            locale = Locale.US,
        )

        assertTrue(status.label!!.startsWith("Sync "))
        assertFalse(status.isStale)
    }

    @Test
    fun `connected old sync is marked stale`() {
        val status = WearSyncStatusFormatter.format(
            lastSyncAtMillis = 100_000L,
            isConnected = true,
            nowMillis = 300_001L,
            locale = Locale.US,
        )

        assertTrue(status.label!!.startsWith("Sync atrasada"))
        assertTrue(status.isStale)
    }

    @Test
    fun `disconnected shows last known sync`() {
        val status = WearSyncStatusFormatter.format(
            lastSyncAtMillis = 100_000L,
            isConnected = false,
            nowMillis = 110_000L,
            locale = Locale.US,
        )

        assertTrue(status.label!!.startsWith("Sin conexion · ultima "))
        assertTrue(status.isStale)
    }
}