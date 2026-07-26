package dev.creapolis.pepinillo.feature.focus.components

import dev.creapolis.pepinillo.domain.timer.FocusTimerState
import dev.creapolis.pepinillo.domain.timer.TimerStatus
import dev.creapolis.pepinillo.domain.timer.progress
import dev.creapolis.pepinillo.feature.focus.FocusMode
import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * Pure-JVM unit tests for [TimerMorph.calculateMorphTarget] — the only non-trivial logic in the
 * Sprint 6 circular→squircle morphing (#492). No Compose, no Robolectric.
 *
 * The 2026-07-24 Judgment Day audit (JD-01 / #501) caught a polarity regression: the function
 * treated `progress` as elapsed while the phone fed it the remaining fraction, so idle/start
 * produced a full squircle and the final stretch produced a circle — the inverse of the spec.
 * These tests encode the corrected contract: [progress] is the **elapsed fraction**, and a
 * separate [TimerMorph.calculateMorphTarget.sessionActive] gate covers Idle/WaitingForNext.
 */
class TimerMorphTest {

    @Test
    fun `returns 0 below the 80 percent elapsed threshold`() {
        assertEquals(0f, morph(progress = 0.5f), 0f)
        assertEquals(0f, morph(progress = 0.0f), 0f)
        // exactly at the threshold boundary → still 0 (morphing starts strictly after)
        assertEquals(0f, morph(progress = TimerMorph.THRESHOLD), 0f)
    }

    @Test
    fun `returns 0_5 at 90 percent elapsed`() {
        assertEquals(0.5f, morph(progress = 0.9f), 0.0001f)
    }

    @Test
    fun `returns 1 at 100 percent elapsed`() {
        assertEquals(1.0f, morph(progress = 1.0f), 0.0001f)
    }

    @Test
    fun `morphs continuously and monotonically across the window`() {
        var previous = morph(0.8f)
        var p = 0.81f
        while (p <= 1.0f) {
            val current = morph(p)
            assert(current >= previous) { "Morph target decreased at elapsed $p: $previous -> $current" }
            previous = current
            p += 0.01f
        }
    }

    @Test
    fun `always 0 for count-up modes regardless of progress`() {
        // Flow and Chrono (no countdown) must never morph.
        assertEquals(0f, TimerMorph.calculateMorphTarget(0.9f, hasCountdown = false, sessionActive = true, reduceMotion = false), 0f)
        assertEquals(0f, TimerMorph.calculateMorphTarget(1.0f, hasCountdown = false, sessionActive = true, reduceMotion = false), 0f)
    }

    @Test
    fun `always 0 when reduce motion is enabled`() {
        // Reduce Motion overrides morphing even for countdown modes near completion.
        assertEquals(0f, TimerMorph.calculateMorphTarget(0.95f, hasCountdown = true, sessionActive = true, reduceMotion = true), 0f)
        assertEquals(0f, TimerMorph.calculateMorphTarget(1.0f, hasCountdown = true, sessionActive = true, reduceMotion = true), 0f)
    }

    @Test
    fun `always 0 when the session is not active`() {
        // Idle / WaitingForNext must never morph even if a stale progress value leaks in.
        assertEquals(0f, TimerMorph.calculateMorphTarget(0.95f, hasCountdown = true, sessionActive = false, reduceMotion = false), 0f)
        assertEquals(0f, TimerMorph.calculateMorphTarget(1.0f, hasCountdown = true, sessionActive = false, reduceMotion = false), 0f)
    }

    @Test
    fun `clamps out-of-range progress without breaking`() {
        assertEquals(0f, morph(-0.1f), 0f)
        assertEquals(1.0f, morph(1.5f), 0.0001f)
    }

    // ───────────── Integration: FocusTimerState.progress → TimerMorph (#501) ─────────────

    /**
     * Reproduces the exact wiring in [dev.creapolis.pepinillo.feature.focus.FocusScreen]:
     * invert the state's *remaining* progress to get the elapsed fraction, then feed it to
     * TimerMorph with the Running/Paused gate. This is the regression that JD-01 caught — the
     * unit tests previously encoded the wrong convention without integrating against the state.
     */
    private fun FocusTimerState.morphTarget(reduceMotion: Boolean = false): Float {
        val sessionActive = status == TimerStatus.Running || status == TimerStatus.Paused
        val elapsed = if (sessionActive) 1f - progress else 0f
        return TimerMorph.calculateMorphTarget(
            progress = elapsed,
            hasCountdown = mode.defaultTotalSeconds != null,
            sessionActive = sessionActive,
            reduceMotion = reduceMotion,
        )
    }

    @Test
    fun `integration - idle Pomodoro stays circular even though remaining progress is 1`() {
        // The original bug: idle state has progress = 1f (full), which the old code read as
        // "fully elapsed" and rendered a full squircle. It must be a circle.
        val idle = FocusTimerState(mode = FocusMode.Pomodoro, status = TimerStatus.Idle)
        assertEquals(0f, idle.morphTarget(), 0f)
    }

    @Test
    fun `integration - just started Pomodoro stays circular`() {
        // remaining ≈ 1f ⇒ elapsed ≈ 0f ⇒ no morph yet.
        val justStarted = FocusTimerState(
            mode = FocusMode.Pomodoro,
            status = TimerStatus.Running,
            totalMillis = 25 * 60 * 1000L,
            elapsedMillis = 1_000L,
        )
        assertEquals(0f, justStarted.morphTarget(), 0f)
    }

    @Test
    fun `integration - last 10 percent remaining produces a high morph`() {
        // 10% remaining ⇒ 90% elapsed ⇒ morph = 0.5.
        val total = 25 * 60 * 1000L
        val nearEnd = FocusTimerState(
            mode = FocusMode.Pomodoro,
            status = TimerStatus.Running,
            totalMillis = total,
            elapsedMillis = (total * 0.9).toLong(),
        )
        assertEquals(0.5f, nearEnd.morphTarget(), 0.0001f)
    }

    @Test
    fun `integration - paused session in the final stretch still morphs`() {
        // Paused must keep the urgency cue (it's still an active countdown, frozen in time).
        val total = 25 * 60 * 1000L
        val pausedNearEnd = FocusTimerState(
            mode = FocusMode.Pomodoro,
            status = TimerStatus.Paused,
            totalMillis = total,
            elapsedMillis = (total * 0.95).toLong(),
        )
        assertEquals(0.75f, pausedNearEnd.morphTarget(), 0.0001f)
    }

    @Test
    fun `integration - waiting for next phase stays circular`() {
        // WaitingForNext pins progress at 1f on the phone; must not render as a squircle.
        val waiting = FocusTimerState(
            mode = FocusMode.Pomodoro,
            status = TimerStatus.WaitingForNext,
        )
        assertEquals(0f, waiting.morphTarget(), 0f)
    }

    @Test
    fun `integration - flow and chrono never morph`() {
        val flow = FocusTimerState(mode = FocusMode.Flow, status = TimerStatus.Running, elapsedMillis = 30 * 60 * 1000L)
        val chrono = FocusTimerState(mode = FocusMode.Chrono, status = TimerStatus.Running, elapsedMillis = 30 * 60 * 1000L)
        assertEquals(0f, flow.morphTarget(), 0f)
        assertEquals(0f, chrono.morphTarget(), 0f)
    }

    @Test
    fun `integration - reduce motion wins over everything`() {
        val total = 25 * 60 * 1000L
        val nearEnd = FocusTimerState(
            mode = FocusMode.Pomodoro,
            status = TimerStatus.Running,
            totalMillis = total,
            elapsedMillis = total, // fully elapsed
        )
        assertEquals(0f, nearEnd.morphTarget(reduceMotion = true), 0f)
    }

    private fun morph(progress: Float): Float =
        TimerMorph.calculateMorphTarget(progress, hasCountdown = true, sessionActive = true, reduceMotion = false)
}
