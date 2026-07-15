package dev.creapolis.pepinillo.data.sync

import android.util.Log
import dev.creapolis.pepinillo.BuildConfig
import dev.creapolis.pepinillo.core.auth.AuthStore
import dev.creapolis.pepinillo.di.ApplicationScope
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.Response
import okhttp3.WebSocket
import okhttp3.WebSocketListener
import okio.ByteString
import org.json.JSONObject
import java.util.concurrent.TimeUnit
import javax.inject.Inject
import javax.inject.Singleton

private const val TAG = "SyncWebSocketClient"
private const val PING_INTERVAL_MS = 30_000L // 30 seconds
private const val PONG_TIMEOUT_MS = 10_000L // 10 seconds to receive pong

@Singleton
class SyncWebSocketClient @Inject constructor(
    private val authStore: AuthStore,
    private val syncEngine: SyncEngine,
    private val settingsSyncEngine: SettingsSyncEngine,
    @param:ApplicationScope private val scope: CoroutineScope,
) {
    private var webSocket: WebSocket? = null

    // @Volatile: these are read/written from multiple threads (OkHttp dispatcher,
    // heartbeat coroutine, caller thread). Volatile gives visibility; the
    // connect()/disconnect() critical sections additionally hold connectionLock
    // to make the read-then-write check atomic and prevent duplicate sockets.
    @Volatile private var isConnected = false
    @Volatile private var shouldConnect = false

    private var reconnectAttempt = 0
    private val maxReconnectDelay = 30_000L // 30 seconds
    private val baseReconnectDelay = 1_000L // 1 second
    private var pingJob: Job? = null
    @Volatile private var awaitingPong = false

    private val connectionLock = Any()

    private val client = OkHttpClient.Builder()
        .readTimeout(0, TimeUnit.MILLISECONDS) // No timeout for WebSocket
        .pingInterval(0, TimeUnit.MILLISECONDS) // We handle pings manually
        .build()

    fun connect() {
        synchronized(connectionLock) {
            if (shouldConnect && isConnected) return
            val token = authStore.getAccessToken()
            if (token == null) {
                // Not authenticated — do not open a socket that would just 401.
                shouldConnect = false
                return
            }
            shouldConnect = true
            val deviceId = authStore.getOrCreateDeviceId()

            val wsUrl = buildWsUrl(deviceId)
            Log.d(TAG, "Connecting to WebSocket...")

            // Pass the access token via the Sec-WebSocket-Protocol subprotocol
            // header instead of the URL query, so it never lands in proxy or
            // server access logs. Backend websocket_handler.go accepts
            // "Sec-WebSocket-Protocol: bearer, <jwt>".
            val request = Request.Builder()
                .url(wsUrl)
                .header("Sec-WebSocket-Protocol", "bearer, $token")
                .build()
            webSocket = client.newWebSocket(request, object : WebSocketListener() {
                override fun onOpen(webSocket: WebSocket, response: Response) {
                    Log.d(TAG, "WebSocket connected")
                    isConnected = true
                    reconnectAttempt = 0
                    startHeartbeat()
                }

                override fun onMessage(webSocket: WebSocket, text: String) {
                    Log.d(TAG, "WebSocket message: $text")
                    handleMessage(text)
                }

                override fun onMessage(webSocket: WebSocket, bytes: ByteString) {
                    // Pong frames are handled by OkHttp at the protocol level,
                    // but any binary message resets our pong awaiting state
                    awaitingPong = false
                }

                override fun onClosed(webSocket: WebSocket, code: Int, reason: String) {
                    Log.d(TAG, "WebSocket closed: $code $reason")
                    isConnected = false
                    stopHeartbeat()
                }

                override fun onFailure(webSocket: WebSocket, t: Throwable, response: Response?) {
                    Log.w(TAG, "WebSocket failure: ${t.message}")
                    isConnected = false
                    stopHeartbeat()
                    scheduleReconnect()
                }
            })
        }
    }

    fun disconnect() {
        synchronized(connectionLock) {
            shouldConnect = false
            stopHeartbeat()
            webSocket?.close(1000, "App backgrounded")
            webSocket = null
            isConnected = false
            reconnectAttempt = 0
        }
    }

    private fun startHeartbeat() {
        stopHeartbeat()
        pingJob = scope.launch {
            while (isActive && isConnected) {
                delay(PING_INTERVAL_MS)
                if (!isConnected) break
                awaitingPong = true
                val sent = webSocket?.send("{\"type\":\"ping\"}") ?: false
                if (!sent) {
                    Log.w(TAG, "Heartbeat ping failed to send, triggering reconnect")
                    isConnected = false
                    scheduleReconnect()
                    break
                }
                delay(PONG_TIMEOUT_MS)
                if (awaitingPong) {
                    Log.w(TAG, "Pong timeout, triggering reconnect")
                    webSocket?.cancel()
                    isConnected = false
                    scheduleReconnect()
                    break
                }
            }
        }
    }

    private fun stopHeartbeat() {
        pingJob?.cancel()
        pingJob = null
        awaitingPong = false
    }

    private fun handleMessage(text: String) {
        // Run JSON parsing + sync engine work off the main thread. The shared
        // @param:ApplicationScope is confined to Dispatchers.Main (FocusEngine and
        // SoundscapeManager rely on that single-thread guarantee), so we override
        // the dispatcher only for this push-driven path. SyncEngine/SettingsSyncEngine
        // serialize work through the shared SyncLock.
        scope.launch(Dispatchers.Default) {
            try {
                val json = JSONObject(text)
                when (json.optString("type")) {
                    "pong" -> awaitingPong = false
                    "task_updated" -> syncEngine.syncTasks()
                    "sessions_synced" -> syncEngine.syncSessions()
                    "settings_updated" -> settingsSyncEngine.syncSettings()
                    "stats_updated" -> syncEngine.syncDailyStats()
                    "sync_required" -> syncEngine.syncAll()
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error handling WebSocket message", e)
            }
        }
    }

    private fun scheduleReconnect() {
        val hasToken = authStore.getAccessToken() != null
        if (!shouldAttemptReconnect(reconnectAttempt, hasToken, shouldConnect)) {
            when {
                !shouldConnect ->
                    Log.d(TAG, "Skipping reconnect (disconnect requested)")
                !hasToken -> {
                    Log.d(TAG, "No access token; stopping reconnect after logout")
                    shouldConnect = false
                }
                else ->
                    Log.w(TAG, "Reached max reconnect attempts ($MAX_RECONNECT_ATTEMPTS); giving up")
            }
            return
        }
        val delayMs = calcReconnectDelay(reconnectAttempt, baseReconnectDelay, maxReconnectDelay)
        reconnectAttempt++
        Log.d(TAG, "Scheduling reconnect in ${delayMs}ms (attempt $reconnectAttempt)")
        scope.launch {
            delay(delayMs)
            if (!isConnected && shouldConnect) connect()
        }
    }

    private fun buildWsUrl(deviceId: String): String =
        buildWsUrlPure(wsBaseFrom(BuildConfig.BASE_URL), deviceId)

    companion object {
        internal const val MAX_RECONNECT_ATTEMPTS = 20

        /** Pure: exponential backoff delay capped at [max]. Exposed for tests. */
        internal fun calcReconnectDelay(
            attempt: Int,
            base: Long = 1_000L,
            max: Long = 30_000L,
        ): Long = (base * (1 shl minOf(attempt, 5))).coerceAtMost(max)

        /**
         * Pure reconnect decision: schedule another attempt only while the caller
         * still wants a connection, we hold an access token, and we have not
         * exceeded [maxAttempts]. Exposed for tests.
         */
        internal fun shouldAttemptReconnect(
            attempt: Int,
            hasToken: Boolean,
            wantConnect: Boolean,
            maxAttempts: Int = MAX_RECONNECT_ATTEMPTS,
        ): Boolean = wantConnect && hasToken && attempt < maxAttempts

        /** Pure: convert an http(s) base URL to its ws(s) form. Exposed for tests. */
        internal fun wsBaseFrom(baseUrl: String): String =
            baseUrl.trimEnd('/').replace("https://", "wss://").replace("http://", "ws://")

        /** Pure: build the WebSocket URL. Deliberately contains NO token. */
        internal fun buildWsUrlPure(wsBase: String, deviceId: String): String =
            "$wsBase/ws?deviceId=$deviceId"
    }
}
