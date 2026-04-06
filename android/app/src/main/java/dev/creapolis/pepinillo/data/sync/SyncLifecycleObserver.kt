package dev.creapolis.pepinillo.data.sync

import android.util.Log
import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.LifecycleOwner
import dev.creapolis.pepinillo.core.identity.IdentityManager
import javax.inject.Inject
import javax.inject.Singleton

private const val TAG = "SyncLifecycleObserver"

@Singleton
class SyncLifecycleObserver @Inject constructor(
    private val syncWebSocketClient: SyncWebSocketClient,
    private val identityManager: IdentityManager,
) : DefaultLifecycleObserver {

    override fun onStart(owner: LifecycleOwner) {
        // App came to foreground
        if (identityManager.isAuthenticated()) {
            Log.d(TAG, "App foregrounded, connecting WebSocket")
            syncWebSocketClient.connect()
        }
    }

    override fun onStop(owner: LifecycleOwner) {
        // App went to background
        Log.d(TAG, "App backgrounded, disconnecting WebSocket")
        syncWebSocketClient.disconnect()
    }
}
