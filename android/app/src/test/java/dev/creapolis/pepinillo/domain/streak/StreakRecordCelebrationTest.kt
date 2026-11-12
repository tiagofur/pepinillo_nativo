package dev.creapolis.pepinillo.domain.streak

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Unit tests for the streak-record celebration eligibility rule (#729).
 */
class StreakRecordCelebrationTest {

    @Test
    fun `record at two days with single-day history fires`() {
        // yesterday-only history: previousBest = 1; today's session lifts streak to 2
        assertTrue(
            StreakRecordCelebration.isEligible(
                currentStreak = 2,
                previousBest = 1,
            )
        )
    }

    @Test
    fun `first ever streak does not celebrate`() {
        // day 1: streak 1 > best 0, but trivial records are not celebrated
        assertFalse(
            StreakRecordCelebration.isEligible(
                currentStreak = 1,
                previousBest = 0,
            )
        )
    }

    @Test
    fun `tie with best does not celebrate`() {
        assertFalse(
            StreakRecordCelebration.isEligible(
                currentStreak = 5,
                previousBest = 5,
            )
        )
    }

    @Test
    fun `streak below best does not celebrate`() {
        assertFalse(
            StreakRecordCelebration.isEligible(
                currentStreak = 3,
                previousBest = 7,
            )
        )
    }

    @Test
    fun `previously celebrated value does not celebrate again (latch)`() {
        assertFalse(
            StreakRecordCelebration.isEligible(
                currentStreak = 4,
                previousBest = 3,
                lastCelebrated = 4,
            )
        )
    }

    @Test
    fun `streak beyond last celebrated fires even if best is stale`() {
        assertTrue(
            StreakRecordCelebration.isEligible(
                currentStreak = 8,
                previousBest = 2,
                lastCelebrated = 3,
            )
        )
    }

    @Test
    fun `disabled toggle suppresses everything`() {
        assertFalse(
            StreakRecordCelebration.isEligible(
                currentStreak = 10,
                previousBest = 2,
                enabled = false,
            )
        )
    }

    @Test
    fun `previousBest including today never fires`() {
        // The caller MUST exclude today's row from previousBest history. Including it
        // yields previousBest >= currentStreak, so this documents the guard.
        val current = 6
        val bestIncludingToday = 6
        assertFalse(
            StreakRecordCelebration.isEligible(
                currentStreak = current,
                previousBest = bestIncludingToday,
            )
        )
    }
}
