package dev.creapolis.pepinillo.domain.streak

/**
 * Pure, stateless rule for when a completed focus session deserves a "new streak record"
 * celebration (#729). Mirrors the calm-by-design product rule: celebrate only genuine
 * breakthroughs, never trivial firsts or ties.
 *
 * Eligibility (all must hold):
 *  - [enabled] — user toggle (`celebrateStreakRecords`).
 *  - [currentStreak] ≥ [MIN_CELEBRATED_STREAK] — a first-ever streak (1 day) makes
 *    everything a record; celebrating it dilutes the moment. Day 2 is the critical
 *    retention peak and is the first celebration.
 *  - [currentStreak] > [previousBest] — strictly beats the best streak, with today's
 *    row EXCLUDED from the history the caller used to compute [previousBest] (if today
 *    is included, previousBest ≥ currentStreak always holds and nothing ever fires).
 *  - [currentStreak] > [lastCelebrated] — anti-repeat latch (survives process death);
 *    the daily granularity of streaks already prevents double-firing within one day.
 */
object StreakRecordCelebration {

    /** Minimum streak length worth celebrating. */
    const val MIN_CELEBRATED_STREAK = 2

    fun isEligible(
        currentStreak: Int,
        previousBest: Int,
        lastCelebrated: Int = 0,
        enabled: Boolean = true,
    ): Boolean =
        enabled &&
            currentStreak >= MIN_CELEBRATED_STREAK &&
            currentStreak > previousBest &&
            currentStreak > lastCelebrated
}
