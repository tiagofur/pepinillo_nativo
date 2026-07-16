package dev.creapolis.pepinillo.domain.tasks

import dev.creapolis.pepinillo.feature.tasks.model.RecurrenceOption
import java.util.Calendar

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

    /**
     * Returns a [Calendar] representing the start (midnight) of the local day containing
     * [millis], in the device's default timezone.
     *
     * This MUST be idempotent: `startOfLocalDay(startOfLocalDay(now).timeInMillis)` must
     * return the same instant as `startOfLocalDay(now)`. Previously this read Y/M/D from a
     * local-tz calendar but wrote into a UTC calendar — the resulting "UTC midnight"
     * instant, when fed back in, re-interpreted to the *previous* local day in timezones
     * behind UTC (e.g. UTC-3), causing recurring tasks to advance by 0 days instead of 1.
     *
     * Using the local timezone for both read and write keeps the operation idempotent and
     * matches user intent: "due today" means the local calendar day, not a UTC-aligned one.
     */
    fun startOfLocalDay(millis: Long = System.currentTimeMillis()): Calendar {
        return Calendar.getInstance().apply {
            timeInMillis = millis
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
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