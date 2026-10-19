package dev.creapolis.pepinillo.feature.calendar

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Unit tests for the weekday-header modulo helper (super-review P2h).
 *
 * The old `firstDay + index` computation produced Calendar.DAY_OF_WEEK values of 8–13 for
 * Monday-first locales, so `Calendar.set(DAY_OF_WEEK, …)` rolled to arbitrary days and the
 * header row showed wrong/duplicated weekday abbreviations. [weekdayForColumn] wraps the sum
 * back into the valid 1..7 range.
 */
class CalendarScreenTest {

    @Test
    fun `weekdayForColumn is identity for Sunday-first locales`() {
        // firstDayOfWeek = 1 (US): columns are Sun..Sat = 1..7
        assertEquals(listOf(1, 2, 3, 4, 5, 6, 7), (0..6).map { weekdayForColumn(1, it) })
    }

    @Test
    fun `weekdayForColumn wraps for Monday-first locales`() {
        // firstDayOfWeek = 2 (most of Europe/LatAm): columns are Mon..Sun = 2..7,1.
        // The old firstDay + index formula returned 8 for the last column.
        assertEquals(listOf(2, 3, 4, 5, 6, 7, 1), (0..6).map { weekdayForColumn(2, it) })
    }

    @Test
    fun `weekdayForColumn wraps for Saturday-first locales`() {
        // firstDayOfWeek = 7 (e.g. some Middle-East locales): columns are Sat..Fri = 7,1..6
        assertEquals(listOf(7, 1, 2, 3, 4, 5, 6), (0..6).map { weekdayForColumn(7, it) })
    }

    @Test
    fun `weekdayForColumn always returns a valid Calendar day constant`() {
        for (firstDay in 1..7) {
            for (index in 0..6) {
                val value = weekdayForColumn(firstDay, index)
                assertTrue("expected 1..7, got $value", value in 1..7)
            }
        }
    }

    @Test
    fun `weekdayForColumn yields each weekday exactly once per row`() {
        for (firstDay in 1..7) {
            val values = (0..6).map { weekdayForColumn(firstDay, it) }
            assertEquals((1..7).toSet(), values.toSet())
        }
    }
}
