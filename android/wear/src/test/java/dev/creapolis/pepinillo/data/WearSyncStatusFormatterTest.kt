package dev.creapolis.pepinillo.data

import android.content.Context
import dev.creapolis.pepinillo.R
import io.mockk.every
import io.mockk.mockk
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import java.util.Locale

class WearSyncStatusFormatterTest {

    private val context: Context = mockk(relaxed = true)

    @Before
    fun setUp() {
        every { context.getString(R.string.sync_waiting) } returns "Esperando primera sync"
        every { context.getString(R.string.sync_no_connection, any()) } answers {
            "Sin conexion · ultima ${it.invocation.args[1]}"
        }
        every { context.getString(R.string.sync_stale, any()) } answers {
            "Sync atrasada ${it.invocation.args[1]}"
        }
        every { context.getString(R.string.sync_ok, any()) } answers {
            "Sync ${it.invocation.args[1]}"
        }
    }

    @Test
    fun `connected without sync shows waiting label`() {
        val status = WearSyncStatusFormatter.format(
            context = context,
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
            context = context,
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
            context = context,
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
            context = context,
            lastSyncAtMillis = 100_000L,
            isConnected = false,
            nowMillis = 110_000L,
            locale = Locale.US,
        )

        assertTrue(status.label!!.startsWith("Sin conexion · ultima "))
        assertTrue(status.isStale)
    }
}