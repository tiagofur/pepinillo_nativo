package dev.creapolis.pepinillo.data.sync

import org.junit.Assert.assertTrue
import org.junit.Test
import java.util.Calendar
import java.util.TimeZone

class MidnightWidgetRefreshSchedulerTest {

    @Test
    fun `millisUntilNextMidnight is positive and under one day`() {
        val now = Calendar.getInstance(TimeZone.getTimeZone("UTC")).apply {
            set(2026, Calendar.JULY, 12, 15, 30, 0)
            set(Calendar.MILLISECOND, 0)
        }
        val delay = MidnightWidgetRefreshScheduler.millisUntilNextMidnight(now)
        assertTrue(delay > 0)
        assertTrue(delay <= 24 * 60 * 60 * 1000L)
    }
}