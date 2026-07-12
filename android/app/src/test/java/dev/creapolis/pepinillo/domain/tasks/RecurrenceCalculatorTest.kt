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
        val base = RecurrenceCalculator.startOfLocalDay()
        val next = RecurrenceCalculator.nextOccurrenceMillis(
            RecurrenceOption.Monthly.rrule!!,
            base.timeInMillis,
        )
        val expected = (base.clone() as Calendar).apply { add(Calendar.MONTH, 1) }.timeInMillis
        assertEquals(expected, next)
    }

    @Test
    fun isSameLocalDay_matchesNormalizedDay() {
        val today = RecurrenceCalculator.startOfLocalDay()
        assertTrue(RecurrenceCalculator.isSameLocalDay(today.timeInMillis, today))
    }
}