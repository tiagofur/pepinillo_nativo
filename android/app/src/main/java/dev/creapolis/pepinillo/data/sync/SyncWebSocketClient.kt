package dev.creapolis.pepinillo.data.sync

import android.util.Log
import dev.creapolis.pepinillo.BuildConfig
import dev.creapolis.pepinillo.core.auth.AuthStore
import dev.creapolis.pepinillo.di.ApplicationScope
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.Response
import okhttp3.WebSocket
import okhttp3.WebSocketListener
import org.json.JSONObject
import java.util.concurrent.TimeUnit
import javax.inject.Inject
import javax.inject.Singleton

private const val TAG = "SyncWebSocketClient"

@Singleton
class SyncWebSocketClient @Inject constructor(
    private val authStore: AuthStore,
    private val syncEngine: SyncEngine,
    private val settingsSyncEngine: SettingsSyncEngine,
    @ApplicationScope private val scope: CoroutineScope,
) {
    private var webSocket: WebSocket? = null
    private var isConnected = false
    private var reconnectAttempt = 0
    private val maxReconnectDelay = 30_000L // 30 seconds
    private val baseReconnectDelay = 1_000L // 1 second

    private val client = OkHttpClient.Builder()
        .readTimeout(0, TimeUnit.MILLISECONDS) // No timeout for WebSocket
        .build()

    fun connect() {
        if (isConnected) return
        val token = authStore.getAccessToken() ?: return
        val deviceId = authStore.getOrCreateDeviceId()

        val wsUrl = buildWsUrl(token, deviceId)
        Log.d(TAG, "Connecting to WebSocket...")

        val request = Request.Builder().url(wsUrl).build()
        webSocket = client.newWebSocket(request, object : WebSocketListener() {
            override fun onOpen(webSocket: WebSocket, response: Response) {
                Log.d(TAG, "WebSocket connected")
                isConnected = true
                reconnectAttempt = 0
            }

            override fun onMessage(webSocket: WebSocket, text: String) {
                Log.d(TAG, "WebSocket message: $text")
                handleMessage(text)
            }

            override fun onClosed(webSocket: WebSocket, code: Int, reason: String) {
                Log.d(TAG, "WebSocket closed: $code $reason")
                isConnected = false
            }

            override fun onFailure(webSocket: WebSocket, t: Throwable, response: Response?) {
                Log.w(TAG, "WebSocket failure: ${t.message}")
                isConnected = false
                scheduleReconnect()
            }
        })
    }

    fun disconnect() {
        webSocket?.close(1000, "App backgrounded")
        webSocket = null
        isConnected = false
        reconnectAttempt = 0
    }

    private fun handleMessage(text: String) {
        scope.launch {
            try {
                val json = JSONObject(text)
                when (json.optString("type")) {
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
        val delay = (baseReconnectDelay * (1 shl minOf(reconnectAttempt, 5)))
            .coerceAtMost(maxReconnectDelay)
        reconnectAttempt++
        Log.d(TAG, "Scheduling reconnect in ${delay}ms (attempt $reconnectAttempt)")
        scope.launch {
            delay(delay)
            if (!isConnected) connect()
        }
    }

    private fun buildWsUrl(token: String, deviceId: String): String {
        // Convert https://host/api/v1/ to wss://host/api/v1/ws?token=...&deviceId=...
        val baseUrl = BuildConfig.BASE_URL.trimEnd('/')
        val wsBase = baseUrl
            .replace("https://", "wss://")
            .replace("http://", "ws://")
        return "$wsBase/ws?token=$token&deviceId=$deviceId"
    }
}
