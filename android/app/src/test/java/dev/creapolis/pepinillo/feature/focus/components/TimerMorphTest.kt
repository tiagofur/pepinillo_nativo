package dev.creapolis.pepinillo.feature.focus.components

import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * Pure-JVM unit tests for [TimerMorph.calculateMorphTarget] — the only non-trivial logic in the
 * Sprint 6 circular→squircle morphing (#492). No Compose, no Robolectric.
 */
class TimerMorphTest {

    @Test
    fun `returns 0 below the 80 percent threshold`() {
        assertEquals(0f, TimerMorph.calculateMorphTarget(progress = 0.5f, hasCountdown = true, reduceMotion = false), 0f)
        assertEquals(0f, TimerMorph.calculateMorphTarget(progress = 0.0f, hasCountdown = true, reduceMotion = false), 0f)
        // exactly at the threshold boundary → still 0 (morphing starts strictly after)
        assertEquals(0f, TimerMorph.calculateMorphTarget(progress = TimerMorph.THRESHOLD, hasCountdown = true, reduceMotion = false), 0f)
    }

    @Test
    fun `returns 0_5 at 90 percent progress`() {
        val result = TimerMorph.calculateMorphTarget(progress = 0.9f, hasCountdown = true, reduceMotion = false)
        assertEquals(0.5f, result, 0.0001f)
    }

    @Test
    fun `returns 1 at 100 percent progress`() {
        val result = TimerMorph.calculateMorphTarget(progress = 1.0f, hasCountdown = true, reduceMotion = false)
        assertEquals(1.0f, result, 0.0001f)
    }

    @Test
    fun `morphs continuously across the window`() {
        // Monotonically increasing and clamped across the 0.8 → 1.0 window.
        var previous = TimerMorph.calculateMorphTarget(0.8f, hasCountdown = true, reduceMotion = false)
        var p = 0.81f
        while (p <= 1.0f) {
            val current = TimerMorph.calculateMorphTarget(p, hasCountdown = true, reduceMotion = false)
            assert(current >= previous) { "Morph target decreased at progress $p: $previous -> $current" }
            previous = current
            p += 0.01f
        }
    }

    @Test
    fun `always 0 for count-up modes regardless of progress`() {
        // Flow and Chrono (no countdown) must never morph.
        assertEquals(0f, TimerMorph.calculateMorphTarget(0.9f, hasCountdown = false, reduceMotion = false), 0f)
        assertEquals(0f, TimerMorph.calculateMorphTarget(1.0f, hasCountdown = false, reduceMotion = false), 0f)
    }

    @Test
    fun `always 0 when reduce motion is enabled`() {
        // Reduce Motion overrides morphing even for countdown modes near completion.
        assertEquals(0f, TimerMorph.calculateMorphTarget(0.95f, hasCountdown = true, reduceMotion = true), 0f)
        assertEquals(0f, TimerMorph.calculateMorphTarget(1.0f, hasCountdown = true, reduceMotion = true), 0f)
    }

    @Test
    fun `clamps out-of-range progress without breaking`() {
        assertEquals(0f, TimerMorph.calculateMorphTarget(-0.1f, hasCountdown = true, reduceMotion = false), 0f)
        assertEquals(1.0f, TimerMorph.calculateMorphTarget(1.5f, hasCountdown = true, reduceMotion = false), 0.0001f)
    }
}
