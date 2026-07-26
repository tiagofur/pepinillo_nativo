package dev.creapolis.pepinillo.presentation

import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * Pins the #502 REMAINING-polarity contract for the Wear squircle morph: the morph ramps in over
 * the LAST 20% of a countdown, which under REMAINING semantics is `progress` falling from
 * REMAINING_TRIGGER (0.2f) → 0f. Before #502 the producers yielded ELAPSED and the morph keyed on
 * `progress > 0.8f`; this test guards against that regression.
 */
class WearTimerMorphTest {

    private val hasCountdown = true
    private val sessionActive = true
    private val reduceMotion = false

    @Test
    fun `stays circular while more than 20 percent remains`() {
        // Full ring (session just started) → no morph.
        assertEquals(0f, WearTimerMorph.calculateMorphTarget(1f, hasCountdown, sessionActive, reduceMotion))
        // Exactly at the trigger → still no morph (ramp starts strictly below).
        assertEquals(0f, WearTimerMorph.calculateMorphTarget(0.2f, hasCountdown, sessionActive, reduceMotion))
        // Just above the trigger.
        assertEquals(0f, WearTimerMorph.calculateMorphTarget(0.3f, hasCountdown, sessionActive, reduceMotion))
    }

    @Test
    fun `ramps to full squircle over the last 20 percent`() {
        // Halfway through the urgency window (10% remaining) → half morphed.
        assertEquals(0.5f, WearTimerMorph.calculateMorphTarget(0.1f, hasCountdown, sessionActive, reduceMotion), 0.0001f)
        // Session complete → full squircle.
        assertEquals(1f, WearTimerMorph.calculateMorphTarget(0f, hasCountdown, sessionActive, reduceMotion), 0.0001f)
    }

    @Test
    fun `count-up modes never morph even at low progress`() {
        // hasCountdown=false short-circuits before the threshold check.
        assertEquals(0f, WearTimerMorph.calculateMorphTarget(0.05f, hasCountdown = false, sessionActive, reduceMotion))
    }

    @Test
    fun `inactive sessions and reduce motion never morph`() {
        assertEquals(0f, WearTimerMorph.calculateMorphTarget(0.05f, hasCountdown, sessionActive = false, reduceMotion))
        assertEquals(0f, WearTimerMorph.calculateMorphTarget(0.05f, hasCountdown, sessionActive, reduceMotion = true))
    }

    @Test
    fun `old elapsed-polarity regression guard`() {
        // If a future change accidentally restores the pre-#502 ELAPSED contract (morph at
        // progress > 0.8), this assertion fails: under REMAINING, 0.9f means "just started" and
        // must NOT morph.
        assertEquals(
            "0.9f means session just started under REMAINING — must not morph",
            0f,
            WearTimerMorph.calculateMorphTarget(0.9f, hasCountdown, sessionActive, reduceMotion),
        )
    }
}
