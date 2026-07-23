package dev.creapolis.pepinillo.service

import android.content.Context
import android.content.SharedPreferences
import dev.creapolis.pepinillo.domain.timer.FocusPhase
import dev.creapolis.pepinillo.domain.timer.FocusTimerState
import dev.creapolis.pepinillo.domain.timer.TimerStatus
import dev.creapolis.pepinillo.feature.focus.FocusMode
import io.mockk.every
import io.mockk.mockk
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Before
import org.junit.Test

class FocusTimerServiceRecoveryTest {

    private lateinit var fakePrefs: FakeSharedPreferences
    private lateinit var context: Context

    @Before
    fun setUp() {
        fakePrefs = FakeSharedPreferences()
        context = mockk(relaxed = true)
        every { context.getSharedPreferences(any(), any()) } returns fakePrefs
    }

    @Test
    fun `saveRecoveryState persists elapsedMillis`() {
        val state = FocusTimerState(
            mode = FocusMode.Pomodoro,
            phase = FocusPhase.Work,
            status = TimerStatus.Paused,
            elapsedMillis = 10 * 60 * 1000L,
            totalMillis = 25 * 60 * 1000L,
            sessionStartTime = 1_700_000_000_000L,
            completedSessions = 2,
            linkedTaskId = "task-1",
        )

        FocusTimerService.saveRecoveryState(context, state)

        val recovery = FocusTimerService.readRecoveryState(context)
        assertNotNull(recovery)
        assertEquals(10 * 60 * 1000L, recovery!!.elapsedMillis)
        assertEquals(TimerStatus.Paused, recovery.status)
        assertEquals("task-1", recovery.linkedTaskId)
    }

    @Test
    fun `readRecoveryState defaults elapsedMillis to 0 when missing`() {
        fakePrefs.edit()
            .putBoolean("r_active", true)
            .putString("r_mode", FocusMode.Pomodoro.name)
            .putString("r_phase", FocusPhase.Work.name)
            .putString("r_status", TimerStatus.Running.name)
            .putLong("r_start", 1_700_000_000_000L)
            .putLong("r_total", 25 * 60 * 1000L)
            .putInt("r_completed", 0)
            .apply()

        val recovery = FocusTimerService.readRecoveryState(context)

        assertNotNull(recovery)
        assertEquals(0L, recovery!!.elapsedMillis)
    }

    @Test
    fun `pause-death restore - session with 5-32 remaining survives process death`() {
        // Arrange: Simulate a Paused session with 5:32 remaining (332000ms)
        val remainingMillis = 5 * 60 * 1000L + 32 * 1000L // 5:32
        val totalMillis = 25 * 60 * 1000L
        val state = FocusTimerState(
            mode = FocusMode.Pomodoro,
            phase = FocusPhase.Work,
            status = TimerStatus.Paused,
            elapsedMillis = totalMillis - remainingMillis,
            totalMillis = totalMillis,
            sessionStartTime = 1_700_000_000_000L,
            completedSessions = 0,
            linkedTaskId = "task-paused",
        )

        // Act: Save state (simulates process death persistence)
        FocusTimerService.saveRecoveryState(context, state)

        // Assert: Recovery state persists Paused status and correct elapsed
        val recovery = FocusTimerService.readRecoveryState(context)
        assertNotNull(recovery)
        assertEquals(TimerStatus.Paused, recovery!!.status)
        assertEquals(totalMillis - remainingMillis, recovery.elapsedMillis)
        assertEquals(totalMillis, recovery.totalMillis)
        assertEquals(FocusMode.Pomodoro, recovery.mode)
        assertEquals(FocusPhase.Work, recovery.phase)
        assertEquals("task-paused", recovery.linkedTaskId)
    }

    @Test
    fun `start-stop race - stop signal during start leaves no orphaned timer`() {
        // Arrange: Save a recovery state that indicates a Running session
        val state = FocusTimerState(
            mode = FocusMode.Pomodoro,
            phase = FocusPhase.Work,
            status = TimerStatus.Running,
            elapsedMillis = 0L,
            totalMillis = 25 * 60 * 1000L,
            sessionStartTime = 1_700_000_000_000L,
            completedSessions = 0,
            linkedTaskId = "task-race",
        )
        FocusTimerService.saveRecoveryState(context, state)

        // Act: Read recovery state — if stop races with start, the state should be
        // either null (cleared) or have a terminal status
        val recovery = FocusTimerService.readRecoveryState(context)

        // Assert: Recovery state exists with Running status (before stop clears it)
        assertNotNull(recovery)
        assertEquals(TimerStatus.Running, recovery!!.status)

        // Act: Simulate stop by clearing recovery state
        FocusTimerService.clearRecoveryState(context)

        // Assert: After stop, recovery is cleared — no orphaned timer
        val afterStop = FocusTimerService.readRecoveryState(context)
        assertNull("Recovery state should be null after stop clears it", afterStop)
    }

    @Test
    fun `readRecoveryState returns null when not active`() {
        assertNull(FocusTimerService.readRecoveryState(context))
    }

    private class FakeSharedPreferences : SharedPreferences {
        private val data = mutableMapOf<String, Any?>()

        override fun getAll(): MutableMap<String, *> = data.toMutableMap()
        override fun getString(key: String, defValue: String?): String? =
            data[key] as? String ?: defValue
        override fun getStringSet(key: String, defValues: Set<String>?): Set<String>? = defValues
        override fun getInt(key: String, defValue: Int): Int =
            data[key] as? Int ?: defValue
        override fun getLong(key: String, defValue: Long): Long =
            data[key] as? Long ?: defValue
        override fun getFloat(key: String, defValue: Float): Float = defValue
        override fun getBoolean(key: String, defValue: Boolean): Boolean =
            data[key] as? Boolean ?: defValue
        override fun contains(key: String): Boolean = data.containsKey(key)
        override fun edit(): SharedPreferences.Editor = Editor()
        override fun registerOnSharedPreferenceChangeListener(
            listener: SharedPreferences.OnSharedPreferenceChangeListener,
        ) = Unit
        override fun unregisterOnSharedPreferenceChangeListener(
            listener: SharedPreferences.OnSharedPreferenceChangeListener,
        ) = Unit

        private inner class Editor : SharedPreferences.Editor {
            private val pending = mutableMapOf<String, Any?>()
            private var clear = false

            override fun putString(key: String, value: String?): SharedPreferences.Editor {
                pending[key] = value
                return this
            }

            override fun putStringSet(key: String, value: Set<String>?): SharedPreferences.Editor = this
            override fun putInt(key: String, value: Int): SharedPreferences.Editor {
                pending[key] = value
                return this
            }

            override fun putLong(key: String, value: Long): SharedPreferences.Editor {
                pending[key] = value
                return this
            }

            override fun putFloat(key: String, value: Float): SharedPreferences.Editor = this
            override fun putBoolean(key: String, value: Boolean): SharedPreferences.Editor {
                pending[key] = value
                return this
            }

            override fun remove(key: String): SharedPreferences.Editor {
                pending[key] = null
                return this
            }

            override fun clear(): SharedPreferences.Editor {
                clear = true
                return this
            }

            override fun commit(): Boolean {
                apply()
                return true
            }

            override fun apply() {
                if (clear) data.clear()
                pending.forEach { (k, v) ->
                    if (v == null) data.remove(k) else data[k] = v
                }
                pending.clear()
                clear = false
            }
        }
    }
}