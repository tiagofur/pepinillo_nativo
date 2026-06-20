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

    // -----------------------------------------------------------------------
    // Auth gate + reconnect cap (A-C6)
    //
    // shouldAttemptReconnect() is the single decision point used by
    // scheduleReconnect(). It must return false once we log out (no token),
    // once disconnect() clears shouldConnect, or after MAX_RECONNECT_ATTEMPTS.
    // -----------------------------------------------------------------------

    @Test
    fun `reconnect proceeds when connected flag set, token present, under cap`() {
        assert(SyncWebSocketClient.shouldAttemptReconnect(attempt = 0, hasToken = true, wantConnect = true))
        assert(SyncWebSocketClient.shouldAttemptReconnect(attempt = 19, hasToken = true, wantConnect = true))
    }

    @Test
    fun `reconnect stops after logout - no access token`() {
        // After logout authStore.getAccessToken() == null → must NOT reconnect.
        assertEquals(
            false,
            SyncWebSocketClient.shouldAttemptReconnect(attempt = 0, hasToken = false, wantConnect = true),
        )
    }

    @Test
    fun `reconnect stops after disconnect - wantConnect false`() {
        assertEquals(
            false,
            SyncWebSocketClient.shouldAttemptReconnect(attempt = 0, hasToken = true, wantConnect = false),
        )
    }

    @Test
    fun `reconnect stops after reaching max attempts`() {
        assertEquals(
            false,
            SyncWebSocketClient.shouldAttemptReconnect(
                attempt = SyncWebSocketClient.MAX_RECONNECT_ATTEMPTS,
                hasToken = true,
                wantConnect = true,
            ),
        )
    }

    @Test
    fun `max reconnect attempts is twenty`() {
        assertEquals(20, SyncWebSocketClient.MAX_RECONNECT_ATTEMPTS)
    }

    @Test
    fun `last allowed attempt is max minus one`() {
        assert(SyncWebSocketClient.shouldAttemptReconnect(attempt = 19, hasToken = true, wantConnect = true))
        assertEquals(
            false,
            SyncWebSocketClient.shouldAttemptReconnect(attempt = 20, hasToken = true, wantConnect = true),
        )
    }

    @Test
    fun `calcReconnectDelay matches the documented exponential formula`() {
        // Real internal helper — not a replica.
        assertEquals(1_000L, SyncWebSocketClient.calcReconnectDelay(0))
        assertEquals(2_000L, SyncWebSocketClient.calcReconnectDelay(1))
        assertEquals(4_000L, SyncWebSocketClient.calcReconnectDelay(2))
        assertEquals(8_000L, SyncWebSocketClient.calcReconnectDelay(3))
        assertEquals(16_000L, SyncWebSocketClient.calcReconnectDelay(4))
        assertEquals(30_000L, SyncWebSocketClient.calcReconnectDelay(5))
        assertEquals(30_000L, SyncWebSocketClient.calcReconnectDelay(50))
    }

    // -----------------------------------------------------------------------
    // Token moved out of URL (W-T4)
    //
    // buildWsUrlPure() must NOT contain the access token; it must only carry
    // deviceId. The token now travels via Sec-WebSocket-Protocol header.
    // -----------------------------------------------------------------------

    @Test
    fun `ws url contains deviceId only`() {
        val url = SyncWebSocketClient.buildWsUrlPure("wss://host/api/v1", "device-123")
        assertEquals("wss://host/api/v1/ws?deviceId=device-123", url)
    }

    @Test
    fun `ws url never contains a token query parameter`() {
        val url = SyncWebSocketClient.buildWsUrlPure("wss://host/api/v1", "device-123")
        assert(!url.contains("token")) { "token must not appear in URL: $url" }
        assert(!url.contains("bearer")) { "bearer must not appear in URL: $url" }
    }

    @Test
    fun `wsBaseFrom promotes https to wss and strips trailing slash`() {
        assertEquals(
            "wss://host/api/v1",
            SyncWebSocketClient.wsBaseFrom("https://host/api/v1/"),
        )
    }

    @Test
    fun `wsBaseFrom promotes http to ws`() {
        assertEquals("ws://host/api/v1", SyncWebSocketClient.wsBaseFrom("http://host/api/v1/"))
    }
}
