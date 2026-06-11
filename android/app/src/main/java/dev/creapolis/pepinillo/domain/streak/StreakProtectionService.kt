package dev.creapolis.pepinillo.domain.streak

import dev.creapolis.pepinillo.data.local.entity.DailyStatsEntity
import java.util.Calendar
import java.util.TimeZone

// StreakProtectionService.kt
// Pepinillo — Android
//
// Pure, stateless streak computation with Pro streak-protection.
// Mirrors the algorithm in ios/Domain/Services/StreakProtectionService.swift exactly.
//
// Algorithm
// ---------
// Walk backward from today through daily focus records (newest first).
// A day counts toward the streak if:
//   (a) it had sessionsCompleted > 0, OR
//   (b) it is a "protected miss" — the user is Pro, and no other skip has been
//       consumed within the preceding rolling 7-day window.
//
// "Rolling 7-day window": for each miss we check whether a skip was already
// used within the 7 days immediately before that miss (walking backward,
// "before" = an earlier date). If not, the miss is auto-covered. Max one skip
// per rolling 7-day window.
//
// The function is purely referentially transparent: same inputs → same output.
// No database reads, no Android framework dependencies.
//
// Today-in-progress rule
// ----------------------
// If today has no focus session yet, it is neutral — it does not break the
// streak and does not consume a Pro skip. The streak is computed starting from
// yesterday. A Pro skip can only cover fully-elapsed missed days (yesterday
// and earlier).
//
// Timezone / DST correctness
// --------------------------
// All day normalisation uses a SINGLE calendar instance throughout the call:
//   - The convenience overload defaults to Calendar.getInstance() (device-local),
//     matching iOS's Calendar.current.
//   - A defensive copy is taken at entry so caller-visible mutation is impossible.
//   - "Step back one day" uses calendar.add(DAY_OF_MONTH, -1) rather than
//     subtracting a fixed 86 400 000 ms, matching iOS's
//     calendar.date(byAdding: .day, value: -1, …). This keeps day keys aligned
//     across DST transitions where a day is 23 h or 25 h long.

/** Result of a protected streak computation. */
data class StreakResult(
    /** The computed streak length (with protection applied, if applicable). */
    val days: Int,
    /** True if at least one skipped day was covered by Pro protection. */
    val protectionApplied: Boolean,
) {
    companion object {
        val zero = StreakResult(days = 0, protectionApplied = false)
    }
}

object StreakProtectionService {

    /**
     * Compute the current streak from a pre-built focus-by-day lookup.
     *
     * @param focusByDay  Map of start-of-day epoch millis → whether the user had ≥1 focus session.
     * @param isPro       Whether the user has an active Pro subscription.
     * @param todayStartMs  The start-of-day epoch millis to treat as "today".
     * @param calendar    Calendar instance for day arithmetic (caller supplies timezone).
     *                    The instance is cloned defensively; the caller's instance is NOT mutated.
     */
    fun computeProtectedStreak(
        focusByDay: Map<Long, Boolean>,
        isPro: Boolean,
        todayStartMs: Long,
        calendar: Calendar,
    ): StreakResult {
        if (focusByDay.isEmpty()) return StreakResult.zero

        // Defensive clone so we never mutate the caller-supplied instance.
        val cal = calendar.clone() as Calendar

        // If the user already has a session today, start the walk from today.
        // Otherwise, skip today entirely — an in-progress day is neutral.
        val todayHasFocus = focusByDay[todayStartMs] ?: false
        val startMs: Long = if (todayHasFocus) {
            todayStartMs
        } else {
            cal.timeInMillis = todayStartMs
            cal.add(Calendar.DAY_OF_MONTH, -1)
            startOfDayMillis(cal.timeInMillis, cal)
        }

        // Earliest calendar day that actually has a recorded focus session.
        // A Pro skip can only bridge over missed days that sit between two real
        // focus sessions — it must never extend the streak past the oldest known
        // record, because there's no evidence of a prior streak to protect.
        val earliestFocusMs: Long = focusByDay
            .filter { it.value }
            .keys
            .minOrNull() ?: startMs

        var streak = 0
        var protectionApplied = false

        // lastSkipUsedMs: the start-of-day millis of the most recently consumed
        // skip (if any). We enforce: the next skip must be ≥ 7 calendar days
        // before this one (since we walk backward, "before" = earlier date).
        var lastSkipUsedMs: Long? = null

        var checkMs = startMs

        for (i in 0 until 730) { // Safety cap: max 2 years back
            val hadFocus = focusByDay[checkMs] ?: false

            if (hadFocus) {
                streak++
            } else if (isPro && checkMs >= earliestFocusMs) {
                // Determine whether we can cover this miss with a skip.
                val canSkip: Boolean
                val lastSkip = lastSkipUsedMs
                if (lastSkip != null) {
                    // Days apart between the previous skip (lastSkip) and the current
                    // miss (checkMs). Since lastSkip > checkMs (walking backward),
                    // this is a positive value — matches iOS dateComponents(.day) logic.
                    val daysApart = daysBetween(fromMs = checkMs, toMs = lastSkip, calendar = cal)
                    canSkip = daysApart >= 7
                } else {
                    canSkip = true
                }

                if (canSkip) {
                    streak++
                    protectionApplied = true
                    lastSkipUsedMs = checkMs
                } else {
                    break
                }
            } else {
                break
            }

            // Advance one day backward — calendar-aware to handle DST transitions.
            // iOS equivalent: calendar.date(byAdding: .day, value: -1, to: checkDate)
            cal.timeInMillis = checkMs
            cal.add(Calendar.DAY_OF_MONTH, -1)
            checkMs = startOfDayMillis(cal.timeInMillis, cal)
        }

        return StreakResult(days = streak, protectionApplied = protectionApplied)
    }

    /**
     * Convenience overload: accepts a list of [DailyStatsEntity] rows.
     *
     * Rows with sessionsCompleted == 0 are treated as missed days (not counted).
     * Multiple rows for the same calendar day are OR-merged (any session = has session).
     *
     * Defaults to the device-local timezone (Calendar.getInstance()), matching iOS's
     * Calendar.current. All normalisation — both "today" and history keys — uses this
     * same calendar so they are always comparable.
     */
    fun computeProtectedStreak(
        history: List<DailyStatsEntity>,
        isPro: Boolean,
        todayStartMs: Long = startOfDayMillis(System.currentTimeMillis(), Calendar.getInstance()),
        calendar: Calendar = Calendar.getInstance(),
    ): StreakResult {
        if (history.isEmpty()) return StreakResult.zero

        // Clone once at the entry point. All internal helpers share this copy.
        val cal = calendar.clone() as Calendar

        val focusByDay = mutableMapOf<Long, Boolean>()
        for (stat in history) {
            val day = startOfDayMillis(stat.date, cal)
            val hadSession = stat.sessionsCompleted > 0
            focusByDay[day] = (focusByDay[day] ?: false) || hadSession
        }

        val todayNormalized = startOfDayMillis(todayStartMs, cal)

        return computeProtectedStreak(
            focusByDay = focusByDay,
            isPro = isPro,
            todayStartMs = todayNormalized,
            calendar = cal,
        )
    }

    // -------------------------------------------------------------------------
    // Helpers
    // -------------------------------------------------------------------------

    private const val ONE_DAY_MS = 24L * 60 * 60 * 1000

    /**
     * Returns the number of whole calendar days between [fromMs] and [toMs].
     * Equivalent to iOS `calendar.dateComponents([.day], from: checkDate, to: lastSkip).day`.
     *
     * Both values must already be start-of-day millis for accurate integer counts.
     *
     * Uses rounded ms division: adding ONE_DAY_MS/2 before dividing absorbs the
     * ±1 h DST shift, giving the same result as proper calendar-field arithmetic
     * for all realistic inputs.
     */
    private fun daysBetween(fromMs: Long, toMs: Long, @Suppress("UNUSED_PARAMETER") calendar: Calendar): Int {
        // DST-safe: rounding by half a day absorbs ±1h transitions exactly.
        return ((toMs - fromMs + ONE_DAY_MS / 2) / ONE_DAY_MS).toInt()
    }

    /** Returns the start-of-day epoch millis for the given epoch millis using the supplied calendar. */
    internal fun startOfDayMillis(millis: Long, calendar: Calendar): Long {
        calendar.timeInMillis = millis
        calendar.set(Calendar.HOUR_OF_DAY, 0)
        calendar.set(Calendar.MINUTE, 0)
        calendar.set(Calendar.SECOND, 0)
        calendar.set(Calendar.MILLISECOND, 0)
        return calendar.timeInMillis
    }

    /** Returns the start-of-day epoch millis using the device default timezone. */
    internal fun startOfDayMillis(millis: Long): Long = startOfDayMillis(millis, Calendar.getInstance())

    /** Returns a UTC Calendar, for use in unit tests that need deterministic day keys. */
    internal fun calendarUtc(): Calendar = Calendar.getInstance(TimeZone.getTimeZone("UTC"))
}
