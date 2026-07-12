package dev.creapolis.pepinillo.domain.tasks

import dev.creapolis.pepinillo.feature.tasks.model.RecurrenceOption
import java.util.Calendar
import java.util.TimeZone

/**
 * Computes the next occurrence for Android recurrence presets (parity with iOS RecurrencePreset).
 */
object RecurrenceCalculator {

    fun nextOccurrenceMillis(rrule: String, afterMillis: Long): Long {
        val option = RecurrenceOption.fromRrule(rrule)
        if (option == RecurrenceOption.None) return afterMillis

        val cal = startOfLocalDay(afterMillis)
        return when (option) {
            RecurrenceOption.Daily -> cal.apply { add(Calendar.DAY_OF_YEAR, 1) }.timeInMillis
            RecurrenceOption.Weekdays -> {
                cal.add(Calendar.DAY_OF_YEAR, 1)
                while (isWeekend(cal)) {
                    cal.add(Calendar.DAY_OF_YEAR, 1)
                }
                cal.timeInMillis
            }
            RecurrenceOption.Weekly -> cal.apply { add(Calendar.WEEK_OF_YEAR, 1) }.timeInMillis
            RecurrenceOption.Biweekly -> cal.apply { add(Calendar.WEEK_OF_YEAR, 2) }.timeInMillis
            RecurrenceOption.Monthly -> cal.apply { add(Calendar.MONTH, 1) }.timeInMillis
            RecurrenceOption.None -> afterMillis
        }
    }

    fun startOfLocalDay(millis: Long = System.currentTimeMillis()): Calendar {
        val local = Calendar.getInstance().apply { timeInMillis = millis }
        return Calendar.getInstance(TimeZone.getTimeZone("UTC")).apply {
            clear()
            set(Calendar.YEAR, local.get(Calendar.YEAR))
            set(Calendar.MONTH, local.get(Calendar.MONTH))
            set(Calendar.DAY_OF_MONTH, local.get(Calendar.DAY_OF_MONTH))
        }
    }

    fun isSameLocalDay(millis: Long, day: Calendar): Boolean {
        val normalized = startOfLocalDay(millis)
        return normalized.get(Calendar.YEAR) == day.get(Calendar.YEAR) &&
            normalized.get(Calendar.DAY_OF_YEAR) == day.get(Calendar.DAY_OF_YEAR)
    }

    private fun isWeekend(cal: Calendar): Boolean {
        val dow = cal.get(Calendar.DAY_OF_WEEK)
        return dow == Calendar.SATURDAY || dow == Calendar.SUNDAY
    }
}