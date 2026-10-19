package dev.creapolis.pepinillo.domain.tasks

import java.util.Calendar
import java.util.TimeZone

/**
 * Single source of truth for task due-date encoding (super-review C1).
 *
 * Storage contract: `due_date` is stored as **local-midnight epoch millis** of the due
 * calendar day in the device's default timezone — the same encoding quick-add produces
 * and [RecurrenceCalculator.startOfLocalDay] advances. A data-layer migration normalizes
 * legacy UTC-midnight values, so every read can assume local midnight.
 *
 * Material3 [androidx.compose.material3.DatePicker] exchange format: **UTC-midnight**
 * millis of the picked calendar day (`selectedDateMillis`). Convert on the boundary with
 * [fromPickerMillis] / [toPickerMillis] so the two encodings never mix: naive pass-through
 * used to shift due dates by one day in timezones away from UTC (e.g. UTC-4, UTC+5:30),
 * making tasks vanish from the Upcoming filter and show inconsistent badges.
 */
object DueDateEncoding {

    /**
     * Calendar in the default timezone with only the Y/M/D fields set (time cleared),
     * representing the local day containing [millis]. Two normalized calendars compare
     * equal exactly when they denote the same local calendar day.
     */
    fun normalizedLocalDate(millis: Long): Calendar {
        val local = Calendar.getInstance()
        local.timeInMillis = millis
        return Calendar.getInstance().apply {
            clear()
            set(Calendar.YEAR, local.get(Calendar.YEAR))
            set(Calendar.MONTH, local.get(Calendar.MONTH))
            set(Calendar.DAY_OF_MONTH, local.get(Calendar.DAY_OF_MONTH))
        }
    }

    /** Local-midnight epoch millis of the local day containing [millis]. */
    fun startOfLocalDay(millis: Long = System.currentTimeMillis()): Long =
        normalizedLocalDate(millis).timeInMillis

    /**
     * Reinterprets the picker's UTC-midnight instant as local midnight of the *same
     * calendar date* (not the same instant). This is the write-side boundary conversion
     * when the user confirms a DatePicker selection.
     */
    fun fromPickerMillis(pickerMillis: Long): Long {
        val utc = Calendar.getInstance(TimeZone.getTimeZone("UTC"))
        utc.timeInMillis = pickerMillis
        return Calendar.getInstance().apply {
            clear()
            set(Calendar.YEAR, utc.get(Calendar.YEAR))
            set(Calendar.MONTH, utc.get(Calendar.MONTH))
            set(Calendar.DAY_OF_MONTH, utc.get(Calendar.DAY_OF_MONTH))
        }.timeInMillis
    }

    /**
     * Expresses a stored local-midnight due date in the picker's UTC-midnight format
     * (the read-side boundary conversion for `initialSelectedDateMillis`).
     */
    fun toPickerMillis(localMidnightMillis: Long): Long {
        val local = Calendar.getInstance()
        local.timeInMillis = localMidnightMillis
        return Calendar.getInstance(TimeZone.getTimeZone("UTC")).apply {
            clear()
            set(Calendar.YEAR, local.get(Calendar.YEAR))
            set(Calendar.MONTH, local.get(Calendar.MONTH))
            set(Calendar.DAY_OF_MONTH, local.get(Calendar.DAY_OF_MONTH))
        }.timeInMillis
    }

    /** True when [millis] falls on the same local calendar day as [day] (a normalized local calendar). */
    fun isSameLocalDay(millis: Long, day: Calendar): Boolean =
        normalizedLocalDate(millis) == day

    /** True when [millis] falls strictly before the local calendar day [day]. */
    fun isBeforeLocalDay(millis: Long, day: Calendar): Boolean =
        normalizedLocalDate(millis).before(day)
}
