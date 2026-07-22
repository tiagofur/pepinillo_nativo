package dev.creapolis.pepinillo.feature.tasks.detail

import org.junit.Assert.assertEquals
import org.junit.Test
import java.util.Calendar
import java.util.TimeZone

class TaskDetailDatePickerTest {

    @Test
    fun getUtcMidnightOfLocalToday_returnsUtcMidnightMatchingLocalDay() {
        val localCal = Calendar.getInstance()
        val expectedYear = localCal.get(Calendar.YEAR)
        val expectedMonth = localCal.get(Calendar.MONTH)
        val expectedDay = localCal.get(Calendar.DAY_OF_MONTH)

        val utcMidnightMillis = getUtcMidnightOfLocalToday()

        val utcCal = Calendar.getInstance(TimeZone.getTimeZone("UTC")).apply {
            timeInMillis = utcMidnightMillis
        }

        assertEquals(expectedYear, utcCal.get(Calendar.YEAR))
        assertEquals(expectedMonth, utcCal.get(Calendar.MONTH))
        assertEquals(expectedDay, utcCal.get(Calendar.DAY_OF_MONTH))
        assertEquals(0, utcCal.get(Calendar.HOUR_OF_DAY))
        assertEquals(0, utcCal.get(Calendar.MINUTE))
        assertEquals(0, utcCal.get(Calendar.SECOND))
        assertEquals(0, utcCal.get(Calendar.MILLISECOND))
    }
}
