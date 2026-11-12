package dev.creapolis.pepinillo.service

import android.content.Context
import android.util.Log
import androidx.work.ExistingWorkPolicy
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager
import dev.creapolis.pepinillo.data.local.preferences.UserPreferences
import java.util.Calendar
import java.util.concurrent.TimeUnit

/**
 * Schedules the opt-in weekly focus recap notification (default Sunday 18:00 local time).
 *
 * Uses a OneTimeWorkRequest with cascade re-scheduling (each dispatch enqueues the next
 * week) instead of a 7-day PeriodicWorkRequest, which would drift away from the target
 * weekday/time. No exact alarms: a weekly summary tolerates Doze/OEM delay and keeps
 * SCHEDULE_EXACT_ALARM untouched (#730).
 */
object WeeklyRecapScheduler {

    private const val TAG = "WeeklyRecapScheduler"

    const val WORK_NAME = "weekly_recap"

    fun schedule(context: Context, dayOfWeek: Int, hour: Int, minute: Int) {
        val delay = nextTriggerAt(dayOfWeek, hour, minute) - System.currentTimeMillis()
        val request = OneTimeWorkRequestBuilder<WeeklyRecapWorker>()
            .setInitialDelay(delay.coerceAtLeast(0L), TimeUnit.MILLISECONDS)
            .build()
        WorkManager.getInstance(context).enqueueUniqueWork(
            WORK_NAME,
            ExistingWorkPolicy.REPLACE,
            request,
        )
        Log.d(TAG, "Scheduled weekly recap in $delay ms (day=$dayOfWeek $hour:$minute)")
    }

    fun cancel(context: Context) {
        WorkManager.getInstance(context).cancelUniqueWork(WORK_NAME)
    }

    /**
     * Re-arms the recap after reboot or app update. WorkManager already persists the
     * unique work, but the restore re-aligns it with the current preference values.
     * A disabled recap is not cancelled here — the toggle-off already did.
     */
    suspend fun restoreFromPreferences(context: Context, prefs: UserPreferences) {
        if (prefs.weeklyRecapEnabled) {
            schedule(context, prefs.weeklyRecapDayOfWeek, prefs.weeklyRecapHour, prefs.weeklyRecapMinute)
        }
    }

    /**
     * Next occurrence of [dayOfWeek] (a java.util.Calendar day constant, 1-based with
     * SUNDAY=1) at [hour]:[minute] local time; one week ahead if that time already
     * passed. Day arithmetic via [Calendar.DAY_OF_YEAR] (never raw-millisecond math)
     * keeps this DST-safe — same convention as [DailyReminderScheduler.nextTriggerAt].
     */
    fun nextTriggerAt(
        dayOfWeek: Int,
        hour: Int,
        minute: Int,
        now: Calendar = Calendar.getInstance(),
    ): Long {
        val target = (now.clone() as Calendar).apply {
            set(Calendar.HOUR_OF_DAY, hour)
            set(Calendar.MINUTE, minute)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }
        var daysAhead = (dayOfWeek - target.get(Calendar.DAY_OF_WEEK) + 7) % 7
        if (daysAhead == 0 && target.timeInMillis <= now.timeInMillis) daysAhead = 7
        if (daysAhead > 0) target.add(Calendar.DAY_OF_YEAR, daysAhead)
        return target.timeInMillis
    }
}
