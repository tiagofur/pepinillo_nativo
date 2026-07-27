package dev.creapolis.pepinillo.data

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.util.Calendar
import java.util.TimeZone

/**
 * Pure-logic tests for [WearDayReset] (no Context / Robolectric needed).
 *
 * The persistence side ([WearDayReset.maybeResetForNewDay] writing through
 * WearSnapshotStore) is verified via the manual acceptance criteria in
 * issue #549; here we lock down the calendar math and the decision logic.
 */
class WearDayResetTest {

    private val tz = TimeZone.getDefault()

    @Test
    fun `startOfDay truncates to midnight local time`() {
        // 2026-07-27T15:42:13 local — pick a moment well past midnight.
        val cal = Calendar.getInstance(tz).apply {
            clear()
            set(2026, Calendar.JULY, 27, 15, 42, 13)
            set(Calendar.MILLISECOND, 789)
        }
        val anyTimeThatDay = cal.timeInMillis

        val midnight = WearDayReset.startOfDay(anyTimeThatDay)

        val expected = Calendar.getInstance(tz).apply {
            clear()
            set(2026, Calendar.JULY, 27, 0, 0, 0)
            set(Calendar.MILLISECOND, 0)
        }.timeInMillis

        assertEquals(expected, midnight)
        assertTrue("midnight must be <= the input time", midnight <= anyTimeThatDay)
    }

    @Test
    fun `startOfDay is stable across the same day`() {
        val midnight = Calendar.getInstance(tz).apply {
            clear()
            set(2026, Calendar.JULY, 27, 0, 0, 0)
        }.timeInMillis
        val noon = Calendar.getInstance(tz).apply {
            clear()
            set(2026, Calendar.JULY, 27, 12, 0, 0)
        }.timeInMillis
        val late = Calendar.getInstance(tz).apply {
            clear()
            set(2026, Calendar.JULY, 27, 23, 59, 59)
        }.timeInMillis

        assertEquals(WearDayReset.startOfDay(midnight), WearDayReset.startOfDay(noon))
        assertEquals(WearDayReset.startOfDay(noon), WearDayReset.startOfDay(late))
    }

    @Test
    fun `addDays advances exactly one calendar day`() {
        val today = Calendar.getInstance(tz).apply {
            clear()
            set(2026, Calendar.JULY, 27, 0, 0, 0)
        }.timeInMillis
        val tomorrow = WearDayReset.addDays(today, 1)

        val expected = Calendar.getInstance(tz).apply {
            clear()
            set(2026, Calendar.JULY, 28, 0, 0, 0)
        }.timeInMillis

        assertEquals(expected, tomorrow)
        assertEquals(today + 86_400_000L, tomorrow.coerceAtMost(today + 86_400_000L))
    }

    @Test
    fun `computeResetDecision resets when no marker has ever been persisted`() {
        val now = Calendar.getInstance(tz).apply {
            clear()
            set(2026, Calendar.JULY, 27, 9, 0, 0)
        }.timeInMillis

        val decision = WearDayReset.computeResetDecision(savedDayStart = 0L, now = now)

        assertTrue(decision is ResetDecision.Reset)
        assertEquals(WearDayReset.startOfDay(now), decision.todayStart)
    }

    @Test
    fun `computeResetDecision does not reset on the same day`() {
        val noon = Calendar.getInstance(tz).apply {
            clear()
            set(2026, Calendar.JULY, 27, 12, 0, 0)
        }.timeInMillis
        val sameDayMarker = WearDayReset.startOfDay(noon)
        val laterSameDay = Calendar.getInstance(tz).apply {
            clear()
            set(2026, Calendar.JULY, 27, 23, 30, 0)
        }.timeInMillis

        val decision = WearDayReset.computeResetDecision(
            savedDayStart = sameDayMarker,
            now = laterSameDay,
        )

        assertTrue(decision is ResetDecision.NoReset)
        assertEquals(sameDayMarker, decision.todayStart)
    }

    @Test
    fun `computeResetDecision resets when the persisted day is older`() {
        val yesterday = Calendar.getInstance(tz).apply {
            clear()
            set(2026, Calendar.JULY, 26, 18, 0, 0)
        }.timeInMillis
        val savedMarker = WearDayReset.startOfDay(yesterday)
        val todayNow = Calendar.getInstance(tz).apply {
            clear()
            set(2026, Calendar.JULY, 27, 0, 5, 0)
        }.timeInMillis

        val decision = WearDayReset.computeResetDecision(
            savedDayStart = savedMarker,
            now = todayNow,
        )

        assertTrue(decision is ResetDecision.Reset)
        assertNotEquals(savedMarker, decision.todayStart)
        assertEquals(WearDayReset.startOfDay(todayNow), decision.todayStart)
    }

    @Test
    fun `computeResetDecision is idempotent within the same day`() {
        val now = Calendar.getInstance(tz).apply {
            clear()
            set(2026, Calendar.JULY, 27, 9, 0, 0)
        }.timeInMillis

        val first = WearDayReset.computeResetDecision(savedDayStart = 0L, now = now)
        assertTrue(first is ResetDecision.Reset)
        val marker = first.todayStart

        val second = WearDayReset.computeResetDecision(savedDayStart = marker, now = now)
        assertTrue(second is ResetDecision.NoReset)
    }

    @Test
    fun `computeResetDecision handles near-midnight boundary correctly`() {
        // The instant JUST before midnight and the instant AT midnight must map
        // to two consecutive start-of-days (i.e. they differ by one day).
        val justBeforeMidnight = Calendar.getInstance(tz).apply {
            clear()
            set(2026, Calendar.JULY, 27, 23, 59, 59)
            set(Calendar.MILLISECOND, 999)
        }.timeInMillis
        val atMidnight = justBeforeMidnight + 1 // crosses into July 28

        val startBefore = WearDayReset.startOfDay(justBeforeMidnight)
        val startAt = WearDayReset.startOfDay(atMidnight)

        assertNotEquals(startBefore, startAt)
        assertEquals(WearDayReset.addDays(startBefore, 1), startAt)
    }
}
