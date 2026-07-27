package dev.creapolis.pepinillo.data.sync

import androidx.lifecycle.LifecycleOwner
import dev.creapolis.pepinillo.core.identity.IdentityManager
import dev.creapolis.pepinillo.domain.timer.FocusEngine
import io.mockk.every
import io.mockk.mockk
import io.mockk.verify
import org.junit.Before
import org.junit.Test

/**
 * Locks down issue #551 mechanism A: when the app comes to foreground, the
 * observer must call [FocusEngine.onDayChanged] so the Pomodoro cycle counter
 * and "today" flows refresh if the calendar day changed while the app was
 * backgrounded and idle.
 *
 * onDayChanged() is itself idempotent and unit-tested elsewhere; here we only
 * verify the wiring (the call happens on every onStart, before WebSocket logic).
 */
class SyncLifecycleObserverTest {

    private lateinit var syncWebSocketClient: SyncWebSocketClient
    private lateinit var identityManager: IdentityManager
    private lateinit var focusEngine: FocusEngine
    private lateinit var observer: SyncLifecycleObserver
    private val owner: LifecycleOwner = mockk()

    @Before
    fun setUp() {
        syncWebSocketClient = mockk(relaxed = true)
        identityManager = mockk()
        every { identityManager.isAuthenticated() } returns false
        focusEngine = mockk(relaxed = true)
        observer = SyncLifecycleObserver(syncWebSocketClient, identityManager, focusEngine)
    }

    @Test
    fun `onStart invokes focusEngine onDayChanged`() {
        observer.onStart(owner)

        verify(exactly = 1) { focusEngine.onDayChanged() }
    }

    @Test
    fun `onStart calls onDayChanged before connecting the WebSocket`() {
        // Authenticated → WebSocket connect() will be called. onDayChanged must
        // happen first so flows are fresh before any sync runs. We assert order
        // with MockK's ordered verification.
        every { identityManager.isAuthenticated() } returns true

        observer.onStart(owner)

        io.mockk.verifyOrder {
            focusEngine.onDayChanged()
            syncWebSocketClient.connect()
        }
    }

    @Test
    fun `onStart still calls onDayChanged when not authenticated`() {
        // Even without auth (so no WebSocket), the day-change reset must run:
        // local UI (FocusScreen, dashboard) reads the same flows.
        every { identityManager.isAuthenticated() } returns false

        observer.onStart(owner)

        verify(exactly = 1) { focusEngine.onDayChanged() }
        verify(exactly = 0) { syncWebSocketClient.connect() }
    }

    @Test
    fun `onStop disconnects the WebSocket and does not touch the day-change reset`() {
        observer.onStop(owner)

        verify(exactly = 1) { syncWebSocketClient.disconnect() }
        verify(exactly = 0) { focusEngine.onDayChanged() }
    }
}
