package dev.creapolis.pepinillo.domain.celebration

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/**
 * Mirrors the iOS MilestoneDetectionTests (#774): priority, once-only
 * latches, thresholds, and the existing-user guards.
 */
class MilestoneCelebrationTest {

    private val freshLatches = Milestone.Latches(
        firstSessionDone = false,
        lastSessionCount = 0,
        lastBestMinutes = 0,
    )

    @Test
    fun `first session fires only on the literal first session`() {
        assertEquals(
            Milestone.FirstSession(),
            MilestoneCelebration.detect(
                allTimeSessions = 1, streakDays = 1, longestTodayMinutes = 5,
                latches = freshLatches,
            ),
        )
        // Existing user at 412: the OVERDUE session-count celebration —
        // never a fake first.
        assertEquals(
            Milestone.SessionCount(412),
            MilestoneCelebration.detect(
                allTimeSessions = 412, streakDays = 1, longestTodayMinutes = 5,
                latches = freshLatches,
            ),
        )
        // Latch already consumed.
        assertNull(
            MilestoneCelebration.detect(
                allTimeSessions = 1, streakDays = 1, longestTodayMinutes = 5,
                latches = freshLatches.copy(firstSessionDone = true),
            ),
        )
    }

    @Test
    fun `streak day beats session count and personal best`() {
        assertEquals(
            Milestone.StreakDay(7),
            MilestoneCelebration.detect(
                allTimeSessions = 50, streakDays = 7, longestTodayMinutes = 95,
                latches = freshLatches.copy(firstSessionDone = true, lastSessionCount = 10),
            ),
        )
    }

    @Test
    fun `session count crosses only new thresholds`() {
        assertNull(
            MilestoneCelebration.detect(
                allTimeSessions = 11, streakDays = 1, longestTodayMinutes = 0,
                latches = freshLatches.copy(firstSessionDone = true, lastSessionCount = 10),
            ),
        )
        assertEquals(
            Milestone.SessionCount(50),
            MilestoneCelebration.detect(
                allTimeSessions = 50, streakDays = 1, longestTodayMinutes = 0,
                latches = freshLatches.copy(firstSessionDone = true, lastSessionCount = 10),
            ),
        )
    }

    @Test
    fun `personal best requires floor and improvement`() {
        // Below floor.
        assertNull(
            MilestoneCelebration.detect(
                allTimeSessions = 12, streakDays = 1, longestTodayMinutes = 5,
                latches = freshLatches.copy(firstSessionDone = true, lastSessionCount = 12),
            ),
        )
        // Does not beat the latched best.
        assertNull(
            MilestoneCelebration.detect(
                allTimeSessions = 12, streakDays = 1, longestTodayMinutes = 31,
                latches = freshLatches.copy(firstSessionDone = true, lastSessionCount = 12, lastBestMinutes = 45),
            ),
        )
        // Genuine improvement.
        assertEquals(
            Milestone.PersonalBest(52),
            MilestoneCelebration.detect(
                allTimeSessions = 12, streakDays = 1, longestTodayMinutes = 52,
                latches = freshLatches.copy(firstSessionDone = true, lastSessionCount = 12, lastBestMinutes = 45),
            ),
        )
    }

    @Test
    fun `nothing to celebrate returns null`() {
        assertNull(
            MilestoneCelebration.detect(
                allTimeSessions = 7, streakDays = 2, longestTodayMinutes = 20,
                latches = freshLatches.copy(firstSessionDone = true, lastBestMinutes = 60),
            ),
        )
    }
}
