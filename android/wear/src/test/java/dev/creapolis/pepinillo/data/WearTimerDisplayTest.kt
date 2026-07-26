package dev.creapolis.pepinillo.data

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class WearTimerDisplayTest {

    @Test
    fun `countdown tick derives remaining display and progress from phase end`() {
        val totalMs = 25L * 60L * 1000L
        val now = 1_700_000_000_000L
        val state = WearTimerState(
            mode = "Pomodoro",
            status = "Running",
            phaseEndEpochMs = now + 5L * 60L * 1000L + 23L * 1000L,
            totalDurationMs = totalMs,
        )

        val ticked = WearTimerDisplay.tick(state, now)

        assertEquals("05:23", ticked.displayTime)
        // #502: REMAINING polarity — progress is now remaining/total (≈0.215 for 5:23 of 25:00),
        // not the old elapsed fraction (which was ≈0.785). Matches the phone + widget.
        assertTrue("progress=${ticked.progress} should be ~0.215", ticked.progress in 0.21f..0.22f)
    }

    @Test
    fun `count-up tick derives elapsed display and progress from phase start`() {
        val now = 1_700_000_000_000L
        val state = WearTimerState(
            mode = "Flow",
            status = "Running",
            phaseStartEpochMs = now - (3L * 60L * 1000L + 15L * 1000L),
        )

        val ticked = WearTimerDisplay.tick(state, now)

        assertEquals("03:15", ticked.displayTime)
        assertTrue(ticked.progress in 0.05f..0.06f)
    }

    @Test
    fun `paused tick freezes display time and progress from state`() {
        val state = WearTimerState(
            mode = "Pomodoro",
            status = "Paused",
            displayTime = "12:34",
            progress = 0.51f,
            remainingDurationMs = 12L * 60L * 1000L + 34L * 1000L,
        )

        val ticked = WearTimerDisplay.tick(state, state.phaseEndEpochMs + 60_000L)

        assertEquals("12:34", ticked.displayTime)
        assertEquals(0.51f, ticked.progress, 0.0001f)
    }
}