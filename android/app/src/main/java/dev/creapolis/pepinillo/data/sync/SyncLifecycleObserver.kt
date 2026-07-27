package dev.creapolis.pepinillo.data.sync

import android.util.Log
import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.LifecycleOwner
import dev.creapolis.pepinillo.core.identity.IdentityManager
import dev.creapolis.pepinillo.domain.timer.FocusEngine
import javax.inject.Inject
import javax.inject.Singleton

private const val TAG = "SyncLifecycleObserver"

@Singleton
class SyncLifecycleObserver @Inject constructor(
    private val syncWebSocketClient: SyncWebSocketClient,
    private val identityManager: IdentityManager,
    private val focusEngine: FocusEngine,
) : DefaultLifecycleObserver {

    override fun onStart(owner: LifecycleOwner) {
        // Issue #551: refresh the Pomodoro cycle counter + "today" flows if the
        // calendar day changed while the app was backgrounded and idle. The three
        // existing mechanisms (FocusTimerService receiver, tick-loop backstop,
        // restoreState) only cover an active timer or process restart; none fires
        // when the app sits idle in background across midnight. This is the Android
        // counterpart of iOS PepinilloApp.swift's `case .active:` day-change check.
        // onDayChanged() is idempotent (no-op if the day hasn't changed), so this
        // is cheap to call on every foreground transition and is also correct when
        // the process was killed and recreated on a new day: currentDayStartMillis
        // is re-seeded to today in FocusEngine's constructor, but the repository's
        // _currentDayStart still holds yesterday's value until notifyDayChanged()
        // runs — which onDayChanged() triggers.
        focusEngine.onDayChanged()

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
