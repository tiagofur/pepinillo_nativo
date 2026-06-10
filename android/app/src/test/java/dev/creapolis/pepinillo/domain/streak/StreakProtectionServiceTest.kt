package dev.creapolis.pepinillo.domain.streak

// StreakProtectionServiceTest.kt
// Mirrors every case from ios/Tests/AnalyticsFeatureTests/StreakProtectionTests.swift.
//
// Naming convention: use backtick identifiers matching the Swift test descriptions
// so cross-platform review is straightforward.

import dev.creapolis.pepinillo.data.local.entity.DailyStatsEntity
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.util.Calendar
import java.util.TimeZone

class StreakProtectionServiceTest {

    // ── Test helpers ──────────────────────────────────────────────────────────

    /** Fixed UTC calendar — mirrors the UTC Calendar used in StreakProtectionTests.swift. */
    private val calendar: Calendar
        get() {
            val cal = Calendar.getInstance(TimeZone.getTimeZone("UTC"))
            return cal
        }

    /**
     * A fixed "today" start-of-day for deterministic tests.
     * Mirrors: year=2025, month=6 (1-indexed June = Calendar.JUNE), day=15 noon UTC.
     * We normalise to start-of-day (00:00 UTC) since computeProtectedStreak expects that.
     */
    private val todayStartMs: Long
        get() {
            val cal = calendar
            cal.set(2025, Calendar.JUNE, 15, 0, 0, 0)
            cal.set(Calendar.MILLISECOND, 0)
            return cal.timeInMillis
        }

    private val oneDay = 24L * 60 * 60 * 1000

    /** Build a DailyStatsEntity for a given day offset (0 = today, 1 = yesterday, …). */
    private fun stat(daysAgo: Int, sessionsCompleted: Int = 1): DailyStatsEntity =
        DailyStatsEntity(
            date = todayStartMs - daysAgo * oneDay,
            totalMinutes = if (sessionsCompleted > 0) sessionsCompleted * 25 else 0,
            sessionsCompleted = sessionsCompleted,
        )

    private fun compute(history: List<DailyStatsEntity>, isPro: Boolean) =
        StreakProtectionService.computeProtectedStreak(
            history = history,
            isPro = isPro,
            todayStartMs = todayStartMs,
            calendar = calendar,
        )

    // ── Basic cases ───────────────────────────────────────────────────────────

    @Test
    fun `empty history returns zero streak`() {
        val result = compute(history = emptyList(), isPro = false)
        assertEquals(StreakResult.zero, result)
    }

    @Test
    fun `empty history Pro returns zero streak`() {
        val result = compute(history = emptyList(), isPro = true)
        assertEquals(StreakResult.zero, result)
    }

    @Test
    fun `no missed days — full consecutive streak`() {
        // Today + 4 prior days = 5-day streak
        val history = (0 until 5).map { stat(daysAgo = it) }
        val result = compute(history = history, isPro = false)
        assertEquals(5, result.days)
        assertFalse(result.protectionApplied)
    }

    @Test
    fun `no missed days Pro — same as free`() {
        val history = (0 until 5).map { stat(daysAgo = it) }
        val result = compute(history = history, isPro = true)
        assertEquals(5, result.days)
        assertFalse(result.protectionApplied)
    }

    // ── Free user breaks on miss ──────────────────────────────────────────────

    @Test
    fun `free user one missed day breaks streak`() {
        // Days 0 (today), 1, skip 2, 3, 4
        val history = listOf(0, 1, 3, 4).map { stat(daysAgo = it) }
        val result = compute(history = history, isPro = false)
        assertEquals(2, result.days) // today + yesterday
        assertFalse(result.protectionApplied)
    }

    // ── Pro protection: one miss covered ─────────────────────────────────────

    @Test
    fun `Pro user one missed day is auto-covered`() {
        // Today, skip 1, days 2-5 → should yield 6 days with protection
        val history = listOf(0, 2, 3, 4, 5).map { stat(daysAgo = it) }
        val result = compute(history = history, isPro = true)
        assertEquals(6, result.days)
        assertTrue(result.protectionApplied)
    }

    // ── Two misses within 7 days breaks streak on the second ─────────────────

    @Test
    fun `Pro user two misses within 7 days — second breaks streak`() {
        // Today (0), skip 1, days 2-3, skip 4 (second miss within 7 days), day 5
        // First skip at 1 → second skip at 4 (only 3 days apart) → must break at 4
        val history = listOf(0, 2, 3, 5).map { stat(daysAgo = it) }
        val result = compute(history = history, isPro = true)
        // Walk: day 0 ✓(1), day 1 skip(2, protection), day 2 ✓(3), day 3 ✓(4),
        //        day 4 miss again — last skip at day 1, daysApart=3 < 7 → break
        assertEquals(4, result.days)
        assertTrue(result.protectionApplied)
    }

    // ── Boundary: exactly 7 days between skips ────────────────────────────────

    @Test
    fun `Pro user second skip exactly 7 days after first is allowed`() {
        // Skip at day 1, then skip again at day 8 (7 days apart).
        // Active days: 0, 2-7, 9-10
        val daysActive = mutableListOf(0)
        daysActive += (2..7).toList()
        daysActive += listOf(9, 10)
        val history = daysActive.map { stat(daysAgo = it) }
        val result = compute(history = history, isPro = true)
        // Skips at day 1 and day 8 (8-1 = 7 days apart → allowed)
        // Expected: 0+skip+2+3+4+5+6+7+skip+9+10 = 11 days
        assertEquals(11, result.days)
        assertTrue(result.protectionApplied)
    }

    @Test
    fun `Pro user second skip only 6 days after first — breaks`() {
        // Skip at day 1, miss again at day 7 (only 6 days apart).
        // Active days: 0, 2-6, 8-9
        val daysActive = mutableListOf(0)
        daysActive += (2..6).toList()
        daysActive += listOf(8, 9)
        val history = daysActive.map { stat(daysAgo = it) }
        val result = compute(history = history, isPro = true)
        // After skipping day 1, streak covers today(0), skip(1), 2,3,4,5,6 → then day 7 miss
        // last skip was at 1, days apart = 6 < 7 → break at day 7
        assertEquals(7, result.days)
        assertTrue(result.protectionApplied)
    }

    // ── Miss on first day (yesterday missed with today active) ────────────────

    @Test
    fun `Pro miss on day 1 (yesterday), today active`() {
        // Only today + days 2-4, yesterday (1) missed
        val history = listOf(0, 2, 3, 4).map { stat(daysAgo = it) }
        val result = compute(history = history, isPro = true)
        assertEquals(5, result.days)
        assertTrue(result.protectionApplied)
    }

    // ── Today in-progress (no session yet today) ─────────────────────────────

    @Test
    fun `free no session today is neutral — streak anchors at yesterday`() {
        // No entry for today; yesterday and 2 days ago have sessions.
        // Today is in-progress and should not break the streak.
        val history = listOf(1, 2, 3).map { stat(daysAgo = it) }
        val result = compute(history = history, isPro = false)
        assertEquals(3, result.days) // streak runs from yesterday back 3 days
        assertFalse(result.protectionApplied)
    }

    @Test
    fun `Pro no session today is neutral — streak anchors at yesterday, skip NOT consumed by today`() {
        // No entry for today; previous 4 days active.
        // Today is neutral — the skip must NOT be consumed on today.
        val history = listOf(1, 2, 3, 4).map { stat(daysAgo = it) }
        val result = compute(history = history, isPro = true)
        // Walk starts at yesterday (day 1), all 4 days active → 4-day streak, no skip used.
        assertEquals(4, result.days)
        assertFalse(result.protectionApplied)
    }

    @Test
    fun `Pro no session today with covered miss 3 days ago — skip consumed by miss only`() {
        // Today: no session (neutral). Days 1, 2, 4, 5 active; day 3 is a miss.
        // Walk starts at yesterday (1), covers 1,2, skip day 3, continues 4,5 → 5 days.
        // Skip is consumed by day-3 miss, not by today.
        val history = listOf(1, 2, 4, 5).map { stat(daysAgo = it) }
        val result = compute(history = history, isPro = true)
        assertEquals(5, result.days)
        assertTrue(result.protectionApplied)
    }

    // ── Only today active ─────────────────────────────────────────────────────

    @Test
    fun `single day today returns 1 for both free and Pro`() {
        val history = listOf(stat(daysAgo = 0))
        assertEquals(1, compute(history = history, isPro = false).days)
        assertEquals(1, compute(history = history, isPro = true).days)
    }

    // ── Sessions = 0 treated as no session ────────────────────────────────────

    @Test
    fun `entry with sessionsCompleted = 0 counts as missed day`() {
        val missedDay = DailyStatsEntity(
            date = todayStartMs - oneDay,
            totalMinutes = 0,
            sessionsCompleted = 0,
        )
        val history = listOf(stat(daysAgo = 0), missedDay)
        val freeResult = compute(history = history, isPro = false)
        assertEquals(1, freeResult.days) // only today; yesterday has 0 sessions
    }

    // ── Extra Android-specific edge cases ─────────────────────────────────────

    /** The skip must not extend past the earliest recorded focus day. */
    @Test
    fun `Pro skip does not extend past earliest focus day`() {
        // Only today has a session; day 1 (yesterday) missed.
        // earliestFocusDate == todayStartMs, so day 1 < earliestFocusDate → no skip.
        val history = listOf(stat(daysAgo = 0))
        val result = compute(history = history, isPro = true)
        assertEquals(1, result.days)
        assertFalse(result.protectionApplied)
    }

    /** Duplicate rows for the same calendar day are OR-merged. */
    @Test
    fun `duplicate rows for same day are OR-merged`() {
        val today = stat(daysAgo = 0, sessionsCompleted = 1)
        val todayDuplicate = DailyStatsEntity(
            date = todayStartMs,
            totalMinutes = 25,
            sessionsCompleted = 1,
        )
        val yesterday = stat(daysAgo = 1, sessionsCompleted = 1)
        val history = listOf(today, todayDuplicate, yesterday)
        val result = compute(history = history, isPro = false)
        assertEquals(2, result.days)
        assertFalse(result.protectionApplied)
    }

    // ── S1: earliestFocusDate boundary ───────────────────────────────────────

    /**
     * Today-neutral rule changes the behavior when today has no session.
     *
     * Only day 1 (yesterday) has a session; today has none.
     * Under the today-neutral rule: walk starts at day 1 (yesterday).
     * Day 1 has a real focus session → streak = 1, no skip consumed.
     *
     * The >= guard is still exercised by the Pro-miss-on-yesterday scenario
     * (see `S1 miss one day before earliestFocusDate breaks streak`).
     */
    @Test
    fun `S1 no session today is neutral — walk anchors at yesterday, streak equals 1`() {
        // Only day 1 (yesterday) has a session; today (day 0) has none.
        // Today-neutral: walk starts at day 1. Day 1 has real focus → streak = 1.
        val history = listOf(
            DailyStatsEntity(
                date = todayStartMs - oneDay,
                totalMinutes = 25,
                sessionsCompleted = 1,
            )
        )
        val result = StreakProtectionService.computeProtectedStreak(
            history = history,
            isPro = true,
            todayStartMs = todayStartMs,
            calendar = calendar,
        )
        assertEquals(1, result.days)
        assertFalse(result.protectionApplied)
    }

    @Test
    fun `S1 miss one day before earliestFocusDate breaks streak`() {
        // Sessions on day 0 (today) only. Day 1 (yesterday) is the first miss.
        // earliestFocusMs = todayStartMs (the only real focus day).
        // Walk: day 0 ✓(1), day 1 miss: checkMs(day1) < earliestFocusMs(day0) → break.
        // Streak = 1, no protection (the skip would be before the earliest real day).
        val history = listOf(stat(daysAgo = 0))
        val result = StreakProtectionService.computeProtectedStreak(
            history = history,
            isPro = true,
            todayStartMs = todayStartMs,
            calendar = calendar,
        )
        assertEquals(1, result.days)
        assertFalse(result.protectionApplied)
    }

    // ── DST regression: America/New_York fall-back Nov 2→3 2025 ─────────────
    //
    // On 2025-11-02 (Sunday), clocks fall back at 2 AM EST: the day is 25 h long.
    // A fixed -86400000 ms step from the start of Nov 3 would land at 23:00 on
    // Nov 1 instead of 00:00 Nov 2 — misaligning the map key lookup.
    // Calendar.add(DAY_OF_MONTH, -1) always produces 00:00 local time.
    //
    // Hand-verification:
    //   NY timezone, EST = UTC-5, EDT = UTC-4.
    //   Nov 3 00:00 EST = Nov 3 05:00 UTC → epoch = 1762066800000
    //   Nov 2 00:00 EST = Nov 2 05:00 UTC → epoch = 1761980400000
    //   Difference = 86400000 ms exactly (25h day spans the extra hour internally,
    //   but start-of-day Nov2 is still 05:00 UTC because clocks fell back DURING Nov2).
    //   Actually: Nov 2 starts at EDT (UTC-4) = 04:00 UTC, NOT 05:00.
    //   Nov 3 starts at EST (UTC-5) = 05:00 UTC.
    //   So the raw difference IS 25h = 90000000 ms.
    //   startOfDayMillis(nov3StartMs - 86400000) would give:
    //     nov3StartMs - 86400000 = 1762066800000 - 86400000 = 1761980400000
    //     which is Nov 2 at 01:00 EST (not midnight) — wrong key.
    //   With calendar.add(DAY_OF_MONTH, -1): set to Nov3 00:00, subtract 1 day → Nov2 00:00 ✓.
    //
    // Epoch values (NY timezone):
    //   Nov 3 2025 00:00 Eastern (EST, UTC-5): 2025-11-03T05:00:00Z = 1762066800000
    //   Nov 2 2025 00:00 Eastern (EDT, UTC-4): 2025-11-02T04:00:00Z = 1761976800000
    //   Nov 1 2025 00:00 Eastern (EDT, UTC-4): 2025-11-01T04:00:00Z = 1761890400000

    @Test
    fun `DST fall-back Nov 2-3 2025 NY — streak counts through transition`() {
        val nyTz = TimeZone.getTimeZone("America/New_York")
        val nyCal = Calendar.getInstance(nyTz)

        // Build start-of-day millis for Nov 3, 2 and 1 using the NY calendar.
        fun nyStartOfDay(year: Int, month: Int, day: Int): Long {
            nyCal.set(year, month, day, 0, 0, 0)
            nyCal.set(Calendar.MILLISECOND, 0)
            return nyCal.timeInMillis
        }

        val nov3Ms = nyStartOfDay(2025, Calendar.NOVEMBER, 3)  // "today"
        val nov2Ms = nyStartOfDay(2025, Calendar.NOVEMBER, 2)
        val nov1Ms = nyStartOfDay(2025, Calendar.NOVEMBER, 1)

        // 3-day consecutive streak: Nov 1, 2, 3 all have sessions.
        val history = listOf(
            DailyStatsEntity(date = nov3Ms, totalMinutes = 25, sessionsCompleted = 1),
            DailyStatsEntity(date = nov2Ms, totalMinutes = 25, sessionsCompleted = 1),
            DailyStatsEntity(date = nov1Ms, totalMinutes = 25, sessionsCompleted = 1),
        )

        val result = StreakProtectionService.computeProtectedStreak(
            history = history,
            isPro = false,
            todayStartMs = nov3Ms,
            calendar = Calendar.getInstance(nyTz),
        )

        // All three days should be counted despite the DST fall-back on Nov 2.
        assertEquals(3, result.days)
        assertFalse(result.protectionApplied)
    }

    @Test
    fun `DST spring-forward Mar 8-9 2026 NY — streak counts through transition`() {
        val nyTz = TimeZone.getTimeZone("America/New_York")
        val nyCal = Calendar.getInstance(nyTz)

        fun nyStartOfDay(year: Int, month: Int, day: Int): Long {
            nyCal.set(year, month, day, 0, 0, 0)
            nyCal.set(Calendar.MILLISECOND, 0)
            return nyCal.timeInMillis
        }

        // On Mar 8 2026 clocks spring forward at 2 AM: the day is only 23 h long.
        val mar9Ms  = nyStartOfDay(2026, Calendar.MARCH, 9)  // "today"
        val mar8Ms  = nyStartOfDay(2026, Calendar.MARCH, 8)
        val mar7Ms  = nyStartOfDay(2026, Calendar.MARCH, 7)

        val history = listOf(
            DailyStatsEntity(date = mar9Ms,  totalMinutes = 25, sessionsCompleted = 1),
            DailyStatsEntity(date = mar8Ms,  totalMinutes = 25, sessionsCompleted = 1),
            DailyStatsEntity(date = mar7Ms,  totalMinutes = 25, sessionsCompleted = 1),
        )

        val result = StreakProtectionService.computeProtectedStreak(
            history = history,
            isPro = false,
            todayStartMs = mar9Ms,
            calendar = Calendar.getInstance(nyTz),
        )

        assertEquals(3, result.days)
        assertFalse(result.protectionApplied)
    }

    @Test
    fun `DST fall-back Pro skip across Nov 2-3 2025 NY transition`() {
        // Nov 3 has session, Nov 2 is missed (Pro skip), Nov 1 has session.
        // The skip must be counted across the DST boundary.
        val nyTz = TimeZone.getTimeZone("America/New_York")
        val nyCal = Calendar.getInstance(nyTz)

        fun nyStartOfDay(year: Int, month: Int, day: Int): Long {
            nyCal.set(year, month, day, 0, 0, 0)
            nyCal.set(Calendar.MILLISECOND, 0)
            return nyCal.timeInMillis
        }

        val nov3Ms = nyStartOfDay(2025, Calendar.NOVEMBER, 3)
        val nov2Ms = nyStartOfDay(2025, Calendar.NOVEMBER, 2)
        val nov1Ms = nyStartOfDay(2025, Calendar.NOVEMBER, 1)

        val history = listOf(
            DailyStatsEntity(date = nov3Ms, totalMinutes = 25, sessionsCompleted = 1),
            // Nov 2 is intentionally missing — it's a "miss" to be protected
            DailyStatsEntity(date = nov1Ms, totalMinutes = 25, sessionsCompleted = 1),
        )

        val result = StreakProtectionService.computeProtectedStreak(
            history = history,
            isPro = true,
            todayStartMs = nov3Ms,
            calendar = Calendar.getInstance(nyTz),
        )

        // Nov3(real) + Nov2(protected) + Nov1(real) = 3 days
        assertEquals(3, result.days)
        assertTrue(result.protectionApplied)
    }
}
