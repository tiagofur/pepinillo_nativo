package dev.creapolis.pepinillo.domain.tasks

import dev.creapolis.pepinillo.feature.tasks.model.RecurrenceOption
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.util.Calendar

class RecurrenceCalculatorTest {

    @Test
    fun daily_advancesByOneDay() {
        val base = RecurrenceCalculator.startOfLocalDay()
        val next = RecurrenceCalculator.nextOccurrenceMillis(
            RecurrenceOption.Daily.rrule!!,
            base.timeInMillis,
        )
        val expected = (base.clone() as Calendar).apply { add(Calendar.DAY_OF_YEAR, 1) }.timeInMillis
        assertEquals(expected, next)
    }

    @Test
    fun weekly_advancesByOneWeek() {
        val base = RecurrenceCalculator.startOfLocalDay()
        val next = RecurrenceCalculator.nextOccurrenceMillis(
            RecurrenceOption.Weekly.rrule!!,
            base.timeInMillis,
        )
        val expected = (base.clone() as Calendar).apply { add(Calendar.WEEK_OF_YEAR, 1) }.timeInMillis
        assertEquals(expected, next)
    }

    @Test
    fun weekdays_skipsWeekend() {
        // Friday 2026-07-10
        val friday = Calendar.getInstance().apply {
            set(2026, Calendar.JULY, 10, 12, 0, 0)
            set(Calendar.MILLISECOND, 0)
        }
        val base = RecurrenceCalculator.startOfLocalDay(friday.timeInMillis)
        val next = RecurrenceCalculator.nextOccurrenceMillis(
            RecurrenceOption.Weekdays.rrule!!,
            base.timeInMillis,
        )
        val nextCal = Calendar.getInstance().apply { timeInMillis = next }
        assertEquals(Calendar.MONDAY, nextCal.get(Calendar.DAY_OF_WEEK))
    }

    @Test
    fun monthly_advancesByOneMonth() {
        // Fixed non-overflowing date: a "today"-based base would make this test flaky on
        // month-end days once end-of-month clamping lands (Jan 30 + 1 month -> Feb 28).
        val base = RecurrenceCalculator.startOfLocalDay(dateOf(2025, Calendar.JUNE, 15))
        val next = RecurrenceCalculator.nextOccurrenceMillis(
            RecurrenceOption.Monthly.rrule!!,
            base.timeInMillis,
        )
        assertEquals(dateOf(2025, Calendar.JULY, 15), next)
    }

    @Test
    fun monthly_january31_clampsToFebruary28InNonLeapYear() {
        val next = RecurrenceCalculator.nextOccurrenceMillis(
            RecurrenceOption.Monthly.rrule!!,
            dateOf(2023, Calendar.JANUARY, 31),
        )
        assertEquals(dateOf(2023, Calendar.FEBRUARY, 28), next)
    }

    @Test
    fun monthly_january31_clampsToFebruary29InLeapYear() {
        val next = RecurrenceCalculator.nextOccurrenceMillis(
            RecurrenceOption.Monthly.rrule!!,
            dateOf(2024, Calendar.JANUARY, 31),
        )
        assertEquals(dateOf(2024, Calendar.FEBRUARY, 29), next)
    }

    @Test
    fun monthly_afterClamp_keepsClampedDayWhenTargetMonthAllowsIt() {
        // Clamp semantics (not anchor): once Jan 31 clamps to Feb 28, the series follows
        // the 28th — March has 31 days, so the next occurrence is Mar 28.
        val next = RecurrenceCalculator.nextOccurrenceMillis(
            RecurrenceOption.Monthly.rrule!!,
            dateOf(2023, Calendar.FEBRUARY, 28),
        )
        assertEquals(dateOf(2023, Calendar.MARCH, 28), next)
    }

    private fun dateOf(year: Int, month: Int, day: Int): Long =
        Calendar.getInstance().apply {
            set(year, month, day, 0, 0, 0)
            set(Calendar.MILLISECOND, 0)
        }.timeInMillis

    @Test
    fun isSameLocalDay_matchesNormalizedDay() {
        val today = RecurrenceCalculator.startOfLocalDay()
        assertTrue(RecurrenceCalculator.isSameLocalDay(today.timeInMillis, today))
    }
}