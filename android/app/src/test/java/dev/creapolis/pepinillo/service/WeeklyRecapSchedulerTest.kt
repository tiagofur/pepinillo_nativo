package dev.creapolis.pepinillo.service

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.util.Calendar
import java.util.TimeZone

/**
 * Unit tests for the weekly recap trigger computation (#730). Fixed UTC calendar keeps
 * the assertions deterministic; field-based arithmetic (never raw-millisecond math) is
 * what keeps these correct across DST — the same convention as DailyReminderScheduler.
 */
class WeeklyRecapSchedulerTest {

    private fun utcCalendar(): Calendar = Calendar.getInstance(TimeZone.getTimeZone("UTC"))

    @Test
    fun `nextTriggerAt returns this week's day when it has not passed`() {
        // Thursday 2026-11-12 10:00 UTC → Sunday 2026-11-15 18:00 UTC
        val now = utcCalendar().apply {
            set(2026, Calendar.NOVEMBER, 12, 10, 0, 0)
            set(Calendar.MILLISECOND, 0)
        }
        val trigger = WeeklyRecapScheduler.nextTriggerAt(
            dayOfWeek = Calendar.SUNDAY,
            hour = 18,
            minute = 0,
            now = now,
        )
        val expected = utcCalendar().apply {
            set(2026, Calendar.NOVEMBER, 15, 18, 0, 0)
            set(Calendar.MILLISECOND, 0)
        }.timeInMillis
        assertEquals(expected, trigger)
    }

    @Test
    fun `nextTriggerAt rolls a full week when this week's slot already passed`() {
        // Sunday 2026-11-15 19:00 UTC (slot passed) → Sunday 2026-11-22 18:00 UTC
        val now = utcCalendar().apply {
            set(2026, Calendar.NOVEMBER, 15, 19, 0, 0)
            set(Calendar.MILLISECOND, 0)
        }
        val trigger = WeeklyRecapScheduler.nextTriggerAt(
            dayOfWeek = Calendar.SUNDAY,
            hour = 18,
            minute = 0,
            now = now,
        )
        val expected = utcCalendar().apply {
            set(2026, Calendar.NOVEMBER, 22, 18, 0, 0)
            set(Calendar.MILLISECOND, 0)
        }.timeInMillis
        assertEquals(expected, trigger)
    }

    @Test
    fun `nextTriggerAt hits exactly now rolls one week forward`() {
        // Exactly Sunday 18:00 → next Sunday (a trigger scheduled for "now" would race the dispatch)
        val now = utcCalendar().apply {
            set(2026, Calendar.NOVEMBER, 15, 18, 0, 0)
            set(Calendar.MILLISECOND, 0)
        }
        val trigger = WeeklyRecapScheduler.nextTriggerAt(
            dayOfWeek = Calendar.SUNDAY,
            hour = 18,
            minute = 0,
            now = now,
        )
        val expected = utcCalendar().apply {
            set(2026, Calendar.NOVEMBER, 22, 18, 0, 0)
            set(Calendar.MILLISECOND, 0)
        }.timeInMillis
        assertEquals(expected, trigger)
    }

    @Test
    fun `nextTriggerAt honours a non-Sunday day of week`() {
        // Tuesday 2026-11-10 10:00 UTC → Wednesday 2026-11-11 09:30 UTC
        val now = utcCalendar().apply {
            set(2026, Calendar.NOVEMBER, 10, 10, 0, 0)
            set(Calendar.MILLISECOND, 0)
        }
        val trigger = WeeklyRecapScheduler.nextTriggerAt(
            dayOfWeek = Calendar.WEDNESDAY,
            hour = 9,
            minute = 30,
            now = now,
        )
        val expected = utcCalendar().apply {
            set(2026, Calendar.NOVEMBER, 11, 9, 30, 0)
            set(Calendar.MILLISECOND, 0)
        }.timeInMillis
        assertEquals(expected, trigger)
    }

    @Test
    fun `trigger is always in the future relative to now`() {
        val now = utcCalendar().apply {
            set(2026, Calendar.NOVEMBER, 13, 12, 0, 0)
            set(Calendar.MILLISECOND, 0)
        }
        (Calendar.SUNDAY..Calendar.SATURDAY).forEach { day ->
            val trigger = WeeklyRecapScheduler.nextTriggerAt(dayOfWeek = day, hour = 18, minute = 0, now = now)
            assertTrue(trigger > now.timeInMillis)
        }
    }
}
