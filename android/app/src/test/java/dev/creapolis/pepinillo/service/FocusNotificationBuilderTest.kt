package dev.creapolis.pepinillo.service

import dev.creapolis.pepinillo.domain.timer.FocusPhase
import dev.creapolis.pepinillo.domain.timer.FocusTimerState
import dev.creapolis.pepinillo.domain.timer.TimerStatus
import dev.creapolis.pepinillo.domain.timer.displayTime
import dev.creapolis.pepinillo.feature.focus.FocusMode
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class FocusNotificationBuilderTest {

    @Test
    fun `buildSpec for running pomodoro uses countdown chronometer and avoids frozen time text`() {
        val total = 25 * 60 * 1000L
        val elapsed = 10 * 60 * 1000L + 50 * 1000L // 14:10 remaining
        val state = FocusTimerState(
            mode = FocusMode.Pomodoro,
            phase = FocusPhase.Work,
            status = TimerStatus.Running,
            elapsedMillis = elapsed,
            totalMillis = total,
            completedSessions = 0,
        )

        val nowRealtime = 500_000L
        val spec = FocusNotificationBuilder.buildSpec(
            state = state,
            modeLabel = "Pomodoro",
            phaseLabel = "Focus 1/4",
            statusLabel = "Session in progress",
            taskTitle = null,
            nowElapsedRealtime = nowRealtime,
        )

        assertTrue(spec.isChronometerRunning)
        assertTrue(spec.isCountDown)
        assertEquals(nowRealtime + (total - elapsed), spec.chronometerBaseElapsedRealtime)
        assertFalse(spec.showWhenInHeader)
        assertEquals("Pomodoro — Focus 1/4", spec.title)
        assertEquals("Session in progress", spec.subtitle)
        assertFalse(
            "Fallback contentText must never contain frozen displayTime",
            spec.fallbackContentText.contains(state.displayTime),
        )
        assertTrue(spec.showProgress)
        val expectedProgressPerMil = (((total - elapsed).toFloat() / total.toFloat()) * 1000).toInt()
        assertEquals(expectedProgressPerMil, spec.progressPerMil)
    }

    @Test
    fun `buildSpec for running pomodoro with taskTitle surfaces task in subtitle and fallback`() {
        val state = FocusTimerState(
            mode = FocusMode.Pomodoro,
            phase = FocusPhase.Work,
            status = TimerStatus.Running,
            elapsedMillis = 5 * 60 * 1000L,
            totalMillis = 25 * 60 * 1000L,
        )

        val spec = FocusNotificationBuilder.buildSpec(
            state = state,
            modeLabel = "Pomodoro",
            phaseLabel = "Focus 1/4",
            statusLabel = "Session in progress",
            taskTitle = "Design PiP layout",
            nowElapsedRealtime = 10_000L,
        )

        assertEquals("Design PiP layout", spec.subtitle)
        assertEquals("Design PiP layout", spec.fallbackContentText)
    }

    @Test
    fun `buildSpec for running flow mode uses count-up chronometer without progress bar`() {
        val elapsed = 4 * 60 * 1000L + 15 * 1000L
        val state = FocusTimerState(
            mode = FocusMode.Flow,
            phase = FocusPhase.Work,
            status = TimerStatus.Running,
            elapsedMillis = elapsed,
            totalMillis = 0L,
        )

        val nowRealtime = 1_000_000L
        val spec = FocusNotificationBuilder.buildSpec(
            state = state,
            modeLabel = "Flow",
            phaseLabel = "Flowing...",
            statusLabel = "Session in progress",
            taskTitle = null,
            nowElapsedRealtime = nowRealtime,
        )

        assertTrue(spec.isChronometerRunning)
        assertFalse(spec.isCountDown)
        assertEquals(nowRealtime - elapsed, spec.chronometerBaseElapsedRealtime)
        assertFalse(spec.showProgress)
        assertFalse(spec.showWhenInHeader)
    }

    @Test
    fun `buildSpec for paused session stops chronometer and displays static time`() {
        val total = 25 * 60 * 1000L
        val remaining = 14 * 60 * 1000L + 10 * 1000L // 14:10
        val state = FocusTimerState(
            mode = FocusMode.Pomodoro,
            phase = FocusPhase.Work,
            status = TimerStatus.Paused,
            elapsedMillis = total - remaining,
            totalMillis = total,
        )

        val spec = FocusNotificationBuilder.buildSpec(
            state = state,
            modeLabel = "Pomodoro",
            phaseLabel = "Focus 1/4",
            statusLabel = "Session paused",
            taskTitle = "Write tests",
            nowElapsedRealtime = 250_000L,
        )

        assertFalse(spec.isChronometerRunning)
        assertEquals("14:10", spec.staticTimeText)
        assertFalse(spec.showWhenInHeader)
        assertEquals("Session paused · Write tests", spec.subtitle)
        assertTrue(spec.showProgress)
    }
}
