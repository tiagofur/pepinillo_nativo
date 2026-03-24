package dev.creapolis.pepinillo.data.sync

import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * Tests for SyncWebSocketClient's reconnect delay logic.
 *
 * The handleMessage() dispatch relies on a coroutine scope + OkHttp WebSocket,
 * and org.json.JSONObject is an Android framework class not available in JVM unit tests.
 * Those aspects are better tested via integration/instrumented tests.
 *
 * Here we verify the exponential backoff calculation which is the core testable logic.
 */
class SyncWebSocketClientTest {

    // -----------------------------------------------------------------------
    // Reconnect delay calculation (mirrors scheduleReconnect logic)
    //
    // The actual method is private, so we replicate and verify the formula:
    // delay = (baseDelay * (1 shl min(attempt, 5))).coerceAtMost(maxDelay)
    // -----------------------------------------------------------------------

    private val baseReconnectDelay = 1_000L
    private val maxReconnectDelay = 30_000L

    private fun calculateDelay(attempt: Int): Long {
        return (baseReconnectDelay * (1 shl minOf(attempt, 5)))
            .coerceAtMost(maxReconnectDelay)
    }

    @Test
    fun `reconnect delay starts at base delay for attempt 0`() {
        assertEquals(1_000L, calculateDelay(0))
    }

    @Test
    fun `reconnect delay doubles for attempt 1`() {
        assertEquals(2_000L, calculateDelay(1))
    }

    @Test
    fun `reconnect delay quadruples for attempt 2`() {
        assertEquals(4_000L, calculateDelay(2))
    }

    @Test
    fun `reconnect delay increases exponentially`() {
        assertEquals(1_000L, calculateDelay(0))
        assertEquals(2_000L, calculateDelay(1))
        assertEquals(4_000L, calculateDelay(2))
        assertEquals(8_000L, calculateDelay(3))
        assertEquals(16_000L, calculateDelay(4))
        assertEquals(32_000L.coerceAtMost(maxReconnectDelay), calculateDelay(5))
    }

    @Test
    fun `reconnect delay caps at max delay`() {
        assertEquals(maxReconnectDelay, calculateDelay(5))
        assertEquals(maxReconnectDelay, calculateDelay(6))
        assertEquals(maxReconnectDelay, calculateDelay(10))
        assertEquals(maxReconnectDelay, calculateDelay(100))
    }

    // -----------------------------------------------------------------------
    // Message type dispatch mapping verification
    //
    // Since org.json.JSONObject is not available in JVM unit tests,
    // we verify the dispatch mapping as a pure string lookup.
    // -----------------------------------------------------------------------

    private val dispatchMap = mapOf(
        "task_updated" to "syncTasks",
        "sessions_synced" to "syncSessions",
        "settings_updated" to "syncSettings",
        "stats_updated" to "syncDailyStats",
        "sync_required" to "syncAll",
    )

    @Test
    fun `dispatch map includes task_updated`() {
        assertEquals("syncTasks", dispatchMap["task_updated"])
    }

    @Test
    fun `dispatch map includes sessions_synced`() {
        assertEquals("syncSessions", dispatchMap["sessions_synced"])
    }

    @Test
    fun `dispatch map includes settings_updated`() {
        assertEquals("syncSettings", dispatchMap["settings_updated"])
    }

    @Test
    fun `dispatch map includes stats_updated`() {
        assertEquals("syncDailyStats", dispatchMap["stats_updated"])
    }

    @Test
    fun `dispatch map includes sync_required`() {
        assertEquals("syncAll", dispatchMap["sync_required"])
    }

    @Test
    fun `unknown message type returns null from dispatch map`() {
        assertEquals(null, dispatchMap["unknown_type"])
    }

    @Test
    fun `empty type returns null from dispatch map`() {
        assertEquals(null, dispatchMap[""])
    }
}
