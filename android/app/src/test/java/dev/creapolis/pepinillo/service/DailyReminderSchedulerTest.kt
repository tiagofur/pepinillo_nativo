package dev.creapolis.pepinillo.service

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.util.Calendar
import java.util.TimeZone

class DailyReminderSchedulerTest {

    @Test
    fun `nextTriggerAt returns later today when time not yet passed`() {
        val now = Calendar.getInstance(TimeZone.getTimeZone("UTC")).apply {
            set(2026, Calendar.JULY, 12, 8, 0, 0)
            set(Calendar.MILLISECOND, 0)
        }
        val trigger = DailyReminderScheduler.nextTriggerAt(hour = 9, minute = 30, now = now)
        val expected = (now.clone() as Calendar).apply {
            set(Calendar.HOUR_OF_DAY, 9)
            set(Calendar.MINUTE, 30)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }.timeInMillis
        assertEquals(expected, trigger)
    }

    @Test
    fun `nextTriggerAt rolls to tomorrow when time already passed`() {
        val now = Calendar.getInstance(TimeZone.getTimeZone("UTC")).apply {
            set(2026, Calendar.JULY, 12, 10, 0, 0)
            set(Calendar.MILLISECOND, 0)
        }
        val trigger = DailyReminderScheduler.nextTriggerAt(hour = 9, minute = 0, now = now)
        val expected = (now.clone() as Calendar).apply {
            add(Calendar.DAY_OF_YEAR, 1)
            set(Calendar.HOUR_OF_DAY, 9)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }.timeInMillis
        assertEquals(expected, trigger)
    }

    @Test
    fun `nextTriggerAt is strictly in the future`() {
        val now = Calendar.getInstance()
        val trigger = DailyReminderScheduler.nextTriggerAt(hour = 9, minute = 0, now = now)
        assertTrue(trigger > now.timeInMillis)
    }
}