package dev.creapolis.pepinillo.feature.tasks.detail

import dev.creapolis.pepinillo.domain.tasks.DueDateEncoding
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
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

    // ── Picker <-> storage boundary conversions, canonical local midnight (C1) ──

    @Test
    fun pickerMillis_decodeToLocalMidnightOfPickedDayInUtcMinus4() = inZone("GMT-04:00") {
        val (pickerMillis, expectedLocalMidnight) = tomorrowPickedAndStored()
        assertEquals(expectedLocalMidnight, DueDateEncoding.fromPickerMillis(pickerMillis))
    }

    @Test
    fun pickerMillis_decodeToLocalMidnightOfPickedDayInUtcPlus530() = inZone("GMT+05:30") {
        val (pickerMillis, expectedLocalMidnight) = tomorrowPickedAndStored()
        assertEquals(expectedLocalMidnight, DueDateEncoding.fromPickerMillis(pickerMillis))
    }

    @Test
    fun pickerMillis_roundTripKeepsPickedCalendarDateInUtcMinus4() = inZone("GMT-04:00") {
        val (pickerMillis, _) = tomorrowPickedAndStored()
        assertEquals(
            pickerMillis,
            DueDateEncoding.toPickerMillis(DueDateEncoding.fromPickerMillis(pickerMillis)),
        )
    }

    @Test
    fun pickerMillis_roundTripKeepsPickedCalendarDateInUtcPlus530() = inZone("GMT+05:30") {
        val (pickerMillis, _) = tomorrowPickedAndStored()
        assertEquals(
            pickerMillis,
            DueDateEncoding.toPickerMillis(DueDateEncoding.fromPickerMillis(pickerMillis)),
        )
    }

    @Test
    fun storedDueTomorrow_decodesAsTomorrowNotTodayInUtcMinus4() = inZone("GMT-04:00") {
        val (pickerMillis, _) = tomorrowPickedAndStored()
        val stored = DueDateEncoding.fromPickerMillis(pickerMillis)

        val todayNorm = DueDateEncoding.normalizedLocalDate(System.currentTimeMillis())
        val tomorrowNorm = DueDateEncoding.normalizedLocalDate(System.currentTimeMillis() + 24L * 60 * 60 * 1000)

        assertFalse("stored tomorrow must not decode as today", DueDateEncoding.isSameLocalDay(stored, todayNorm))
        assertFalse("stored tomorrow must not decode as overdue", DueDateEncoding.isBeforeLocalDay(stored, todayNorm))
        assertTrue("stored tomorrow must decode as tomorrow (badge/filter)", DueDateEncoding.isSameLocalDay(stored, tomorrowNorm))
    }

    @Test
    fun storedDueTomorrow_decodesAsTomorrowNotTodayInUtcPlus530() = inZone("GMT+05:30") {
        val (pickerMillis, _) = tomorrowPickedAndStored()
        val stored = DueDateEncoding.fromPickerMillis(pickerMillis)

        val todayNorm = DueDateEncoding.normalizedLocalDate(System.currentTimeMillis())
        val tomorrowNorm = DueDateEncoding.normalizedLocalDate(System.currentTimeMillis() + 24L * 60 * 60 * 1000)

        assertFalse("stored tomorrow must not decode as today", DueDateEncoding.isSameLocalDay(stored, todayNorm))
        assertFalse("stored tomorrow must not decode as overdue", DueDateEncoding.isBeforeLocalDay(stored, todayNorm))
        assertTrue("stored tomorrow must decode as tomorrow (badge/filter)", DueDateEncoding.isSameLocalDay(stored, tomorrowNorm))
    }

    /** Runs [block] with the JVM default timezone swapped to [zoneId], restoring after. */
    private fun inZone(zoneId: String, block: () -> Unit) {
        val original = TimeZone.getDefault()
        TimeZone.setDefault(TimeZone.getTimeZone(zoneId))
        try {
            block()
        } finally {
            TimeZone.setDefault(original)
        }
    }

    /**
     * Simulates picking "due tomorrow" in the Material3 DatePicker: the picker reports
     * UTC-midnight of tomorrow's local calendar date, while storage must hold local
     * midnight of that same date.
     */
    private fun tomorrowPickedAndStored(): Pair<Long, Long> {
        val tomorrow = Calendar.getInstance().apply { add(Calendar.DAY_OF_YEAR, 1) }
        val y = tomorrow.get(Calendar.YEAR)
        val m = tomorrow.get(Calendar.MONTH)
        val d = tomorrow.get(Calendar.DAY_OF_MONTH)

        val pickerMillis = Calendar.getInstance(TimeZone.getTimeZone("UTC")).apply {
            clear()
            set(y, m, d, 0, 0, 0)
        }.timeInMillis
        val expectedLocalMidnight = Calendar.getInstance().apply {
            clear()
            set(y, m, d, 0, 0, 0)
        }.timeInMillis
        return pickerMillis to expectedLocalMidnight
    }
}
