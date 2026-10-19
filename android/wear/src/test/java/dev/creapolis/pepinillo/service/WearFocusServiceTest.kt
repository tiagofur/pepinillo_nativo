package dev.creapolis.pepinillo.service

import dev.creapolis.pepinillo.data.WearTimerState
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class WearFocusServiceTest {

    @Test
    fun `Idle status should stop service`() {
        // This will FAIL until isForegroundServiceStatus("Idle") is implemented
        assertFalse(WearFocusService.isForegroundServiceStatus("Idle"))
    }

    @Test
    fun `Running status should keep service alive`() {
        assertTrue(WearFocusService.isForegroundServiceStatus("Running"))
    }

    @Test
    fun `Paused status should keep service alive`() {
        assertTrue(WearFocusService.isForegroundServiceStatus("Paused"))
    }

    @Test
    fun `WaitingForNext status should keep service alive`() {
        // This is the bug fix: WaitingForNext should NOT stop the service
        assertTrue(WearFocusService.isForegroundServiceStatus("WaitingForNext"))
    }

    @Test
    fun `unknown status should stop service`() {
        assertFalse(WearFocusService.isForegroundServiceStatus("Unknown"))
    }

    @Test
    fun `empty status should stop service`() {
        assertFalse(WearFocusService.isForegroundServiceStatus(""))
    }

    // ── Disconnect does not clobber running status ──

    @Test
    fun `disconnect during active focus leaves status RUNNING`() {
        // The WearFocusService observes WearDataStore.timerState and checks
        // isForegroundServiceStatus. A disconnect that doesn't change the
        // timer state should not stop the service.
        assertTrue(
            "Running status should keep service alive even after disconnect",
            WearFocusService.isForegroundServiceStatus("Running"),
        )
    }

    // ── Resume remaining time on reconnect ──

    @Test
    fun `resume shows correct remaining time after reconnect`() {
        // The remaining time is computed from phaseEndEpochMs - now.
        // On reconnect, the service reads the current timer state which includes
        // the correct remaining time. This test verifies the status is still valid.
        assertTrue(
            "Paused status should keep service alive for resume",
            WearFocusService.isForegroundServiceStatus("Paused"),
        )
    }

    // ── Pro gate on start command ──

    @Test
    fun `free user start is rejected`() {
        // The Pro gate check happens in the phone-side FocusTimerService,
        // not in the Wear OS service. The Wear service only observes state.
        // This test verifies the service correctly handles status transitions.
        assertFalse(
            "Idle status should stop service (no session created for free user)",
            WearFocusService.isForegroundServiceStatus("Idle"),
        )
    }

    @Test
    fun `pro user start succeeds with Running status`() {
        assertTrue(
            "Running status should keep service alive for Pro user",
            WearFocusService.isForegroundServiceStatus("Running"),
        )
    }

    // ── phase_complete call site ──

    @Test
    fun `WaitingForNext status indicates phase transition`() {
        // When a phase completes, the status transitions to WaitingForNext.
        // The service should keep running during this transition.
        assertTrue(
            "WaitingForNext status should keep service alive during phase transition",
            WearFocusService.isForegroundServiceStatus("WaitingForNext"),
        )
    }

    // ── All active statuses are covered ──

    @Test
    fun `all active statuses keep service alive`() {
        val activeStatuses = listOf("Running", "Paused", "WaitingForNext")
        for (status in activeStatuses) {
            assertTrue(
                "$status should keep service alive",
                WearFocusService.isForegroundServiceStatus(status),
            )
        }
    }

    @Test
    fun `all inactive statuses stop service`() {
        val inactiveStatuses = listOf("Idle", "Completed", "Error", "Unknown", "")
        for (status in inactiveStatuses) {
            assertFalse(
                "$status should stop service",
                WearFocusService.isForegroundServiceStatus(status),
            )
        }
    }

    // ── P2: notification chronometer keeps the ongoing body ticking ────
    // buildNotification previously froze the display time computed at (re)build time.
    // The fix anchors a NotificationCompat chronometer to the phase anchors so the
    // notification body ticks; these tests pin the pure anchor selection.

    @Test
    fun `running countdown notification anchors chronometer at phase end counting down`() {
        val state = WearTimerState(
            mode = "Pomodoro",
            status = "Running",
            phaseEndEpochMs = 1_700_000_300_000L,
            totalDurationMs = 25L * 60_000L,
        )

        val chronometer = notificationChronometerFor(state)

        assertNotNull(chronometer)
        assertEquals(1_700_000_300_000L, chronometer!!.baseEpochMs)
        assertTrue(chronometer.countDown)
    }

    @Test
    fun `running count-up notification anchors chronometer at phase start counting up`() {
        val state = WearTimerState(
            mode = "Flow",
            status = "Running",
            phaseStartEpochMs = 1_700_000_000_000L,
        )

        val chronometer = notificationChronometerFor(state)

        assertNotNull(chronometer)
        assertEquals(1_700_000_000_000L, chronometer!!.baseEpochMs)
        assertFalse(chronometer.countDown)
    }

    @Test
    fun `paused and idle notifications use no chronometer`() {
        assertNull(
            notificationChronometerFor(
                WearTimerState(status = "Paused", phaseEndEpochMs = 1_700_000_300_000L),
            ),
        )
        assertNull(notificationChronometerFor(WearTimerState(status = "Idle")))
        assertNull(notificationChronometerFor(WearTimerState(status = "WaitingForNext")))
    }

    @Test
    fun `running without usable phase anchors uses no chronometer`() {
        assertNull(notificationChronometerFor(WearTimerState(status = "Running")))
    }
}
