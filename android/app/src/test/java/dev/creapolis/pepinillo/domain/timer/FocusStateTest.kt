package dev.creapolis.pepinillo.domain.timer

import dev.creapolis.pepinillo.R
import dev.creapolis.pepinillo.feature.focus.FocusMode
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class FocusStateTest {

    @Test
    fun `default state has 25 minutes display`() {
        val state = FocusTimerState()
        assertEquals("25:00", state.displayTime)
    }

    @Test
    fun `countdown shows remaining time`() {
        val state = FocusTimerState(
            mode = FocusMode.Pomodoro,
            totalMillis = 25 * 60 * 1000L,
            elapsedMillis = 5 * 60 * 1000L, // 5 min elapsed
        )
        assertEquals("20:00", state.displayTime) // 25 - 5 = 20
    }

    @Test
    fun `countdown never goes below zero`() {
        val state = FocusTimerState(
            mode = FocusMode.Pomodoro,
            totalMillis = 25 * 60 * 1000L,
            elapsedMillis = 30 * 60 * 1000L, // over time
        )
        assertEquals("00:00", state.displayTime)
    }

    @Test
    fun `flow mode counts up`() {
        val state = FocusTimerState(
            mode = FocusMode.Flow,
            totalMillis = 0L,
            elapsedMillis = 3 * 60 * 1000L + 45 * 1000L, // 3:45
        )
        assertEquals("03:45", state.displayTime)
    }

    @Test
    fun `chrono mode counts up`() {
        val state = FocusTimerState(
            mode = FocusMode.Chrono,
            totalMillis = 0L,
            elapsedMillis = 90 * 1000L, // 1:30
        )
        assertEquals("01:30", state.displayTime)
    }

    @Test
    fun `progress is 1 at start for countdown`() {
        val state = FocusTimerState(
            mode = FocusMode.Pomodoro,
            totalMillis = 25 * 60 * 1000L,
            elapsedMillis = 0L,
        )
        assertEquals(1f, state.progress, 0.001f)
    }

    @Test
    fun `progress is 0_5 at halfway for countdown`() {
        val total = 25 * 60 * 1000L
        val state = FocusTimerState(
            mode = FocusMode.Pomodoro,
            totalMillis = total,
            elapsedMillis = total / 2,
        )
        assertEquals(0.5f, state.progress, 0.001f)
    }

    @Test
    fun `progress is 0 when complete for countdown`() {
        val total = 25 * 60 * 1000L
        val state = FocusTimerState(
            mode = FocusMode.Pomodoro,
            totalMillis = total,
            elapsedMillis = total,
        )
        assertEquals(0f, state.progress, 0.001f)
    }

    @Test
    fun `flow mode progress is 0 at start`() {
        val state = FocusTimerState(
            mode = FocusMode.Flow,
            elapsedMillis = 0L,
        )
        assertEquals(0f, state.progress, 0.001f)
    }

    @Test
    fun `phase label idle pomodoro`() {
        val state = FocusTimerState(mode = FocusMode.Pomodoro, status = TimerStatus.Idle)
        assertEquals(R.string.phase_focus, state.phaseLabelRes)
    }

    @Test
    fun `phase label running pomodoro shows session number`() {
        val state = FocusTimerState(
            mode = FocusMode.Pomodoro,
            status = TimerStatus.Running,
            completedSessions = 2,
        )
        assertEquals(R.string.phase_focus_numbered, state.phaseLabelRes)
    }

    @Test
    fun `phase label short break`() {
        val state = FocusTimerState(
            mode = FocusMode.Pomodoro,
            status = TimerStatus.Running,
            phase = FocusPhase.ShortBreak,
        )
        assertEquals(R.string.phase_short_break, state.phaseLabelRes)
    }

    @Test
    fun `phase label long break`() {
        val state = FocusTimerState(
            mode = FocusMode.Pomodoro,
            status = TimerStatus.Running,
            phase = FocusPhase.LongBreak,
        )
        assertEquals(R.string.phase_long_break, state.phaseLabelRes)
    }

    @Test
    fun `phase label flow running`() {
        val state = FocusTimerState(mode = FocusMode.Flow, status = TimerStatus.Running)
        assertEquals(R.string.phase_flowing, state.phaseLabelRes)
    }

    @Test
    fun `phase label chrono running`() {
        val state = FocusTimerState(mode = FocusMode.Chrono, status = TimerStatus.Running)
        assertEquals(R.string.phase_timing, state.phaseLabelRes)
    }

    @Test
    fun `isComplete true when elapsed exceeds total in running countdown`() {
        val state = FocusTimerState(
            mode = FocusMode.Pomodoro,
            status = TimerStatus.Running,
            totalMillis = 25 * 60 * 1000L,
            elapsedMillis = 25 * 60 * 1000L,
        )
        assertTrue(state.isComplete)
    }

    @Test
    fun `isComplete false for flow mode`() {
        val state = FocusTimerState(
            mode = FocusMode.Flow,
            status = TimerStatus.Running,
            elapsedMillis = 99999999L,
        )
        assertFalse(state.isComplete)
    }

    @Test
    fun `isComplete false when idle`() {
        val state = FocusTimerState(
            mode = FocusMode.Pomodoro,
            status = TimerStatus.Idle,
            totalMillis = 25 * 60 * 1000L,
            elapsedMillis = 25 * 60 * 1000L,
        )
        assertFalse(state.isComplete)
    }

    @Test
    fun `blocks mode display time`() {
        val state = FocusTimerState(
            mode = FocusMode.Blocks,
            totalMillis = 60 * 60 * 1000L,
            elapsedMillis = 15 * 60 * 1000L, // 15 min elapsed
        )
        assertEquals("45:00", state.displayTime) // 60 - 15
    }
}
