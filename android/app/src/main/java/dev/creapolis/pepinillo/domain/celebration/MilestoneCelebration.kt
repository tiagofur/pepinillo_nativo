package dev.creapolis.pepinillo.domain.celebration

/**
 * Milestone celebrations for a just-completed session (#776 Batch D — the
 * Android twin of the iOS unlock in #774). One celebration at a time,
 * priority: first session > streak day > total sessions > personal best.
 *
 * Rules (pure, unit-tested):
 *  - [Milestone.FirstSession] fires only when the completed session is
 *    literally the account's first (== 1) — existing users get their OVERDUE
 *    session-count celebration instead, never a fake first.
 *  - [Milestone.StreakDay] fires on the threshold days (7/14/30) — the
 *    streak-RECORD celebration (#729) stays a separate, older path.
 *  - [Milestone.SessionCount] fires when the all-time total crosses a
 *    threshold that has not been celebrated yet (10/50/100).
 *  - [Milestone.PersonalBest] requires >= [PERSONAL_BEST_FLOOR_MINUTES]
 *    focused minutes AND beating the latched best, so a 2-minute first
 *    session never wears the crown.
 */
sealed interface Milestone {
    data class FirstSession(val totalSessions: Int = 1) : Milestone
    data class StreakDay(val days: Int) : Milestone
    data class SessionCount(val count: Int) : Milestone
    data class PersonalBest(val minutes: Int) : Milestone

    data class Latches(
        val firstSessionDone: Boolean,
        val lastSessionCount: Int,
        val lastBestMinutes: Int,
    )
}

object MilestoneCelebration {

    val SESSION_THRESHOLDS = listOf(10, 50, 100)
    val STREAK_DAYS = listOf(7, 14, 30)
    const val PERSONAL_BEST_FLOOR_MINUTES = 30

    fun detect(
        allTimeSessions: Int,
        streakDays: Int,
        longestTodayMinutes: Int,
        latches: Milestone.Latches,
    ): Milestone? {
        if (!latches.firstSessionDone && allTimeSessions == 1) {
            return Milestone.FirstSession()
        }
        if (STREAK_DAYS.contains(streakDays)) {
            return Milestone.StreakDay(streakDays)
        }
        if (SESSION_THRESHOLDS.any { allTimeSessions >= it && latches.lastSessionCount < it }) {
            return Milestone.SessionCount(allTimeSessions)
        }
        if (longestTodayMinutes >= PERSONAL_BEST_FLOOR_MINUTES &&
            longestTodayMinutes > latches.lastBestMinutes
        ) {
            return Milestone.PersonalBest(longestTodayMinutes)
        }
        return null
    }
}
