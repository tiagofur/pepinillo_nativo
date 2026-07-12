package dev.creapolis.pepinillo.service

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import dev.creapolis.pepinillo.MainActivity
import dev.creapolis.pepinillo.data.local.preferences.UserPreferences
import java.util.Calendar
import java.util.concurrent.TimeUnit

/**
 * Schedules daily focus reminders at the user's chosen local time.
 *
 * Uses [AlarmManager.setAlarmClock] when exact alarms are available (Doze-safe, visible in
 * system UI). Falls back to inexact WorkManager periodic work when exact alarms are denied.
 */
object DailyReminderScheduler {

    private const val TAG = "DailyReminderScheduler"

    const val ACTION_ALARM = "dev.creapolis.pepinillo.DAILY_REMINDER_ALARM"
    const val EXTRA_HOUR = "reminder_hour"
    const val EXTRA_MINUTE = "reminder_minute"
    const val ALARM_REQUEST_CODE = 42_001
    const val WORK_NAME = "daily_reminder"

    fun schedule(context: Context, hour: Int, minute: Int) {
        cancel(context)
        if (canUseExactAlarms(context)) {
            scheduleExactAlarm(context, hour, minute)
            Log.d(TAG, "Scheduled exact alarm for $hour:$minute")
        } else {
            scheduleWorkManagerFallback(context, hour, minute)
            Log.d(TAG, "Exact alarms unavailable — using WorkManager fallback for $hour:$minute")
        }
    }

    fun cancel(context: Context) {
        cancelExactAlarm(context)
        WorkManager.getInstance(context).cancelUniqueWork(WORK_NAME)
    }

    suspend fun restoreFromPreferences(context: Context, prefs: UserPreferences) {
        if (prefs.dailyReminderEnabled) {
            schedule(context, prefs.dailyReminderHour, prefs.dailyReminderMinute)
        } else {
            cancel(context)
        }
    }

    /**
     * Returns the next trigger time (epoch millis) for [hour]:[minute] in the local timezone.
     * If that time today has already passed, returns tomorrow at the same time.
     */
    fun nextTriggerAt(
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
        if (target.timeInMillis <= now.timeInMillis) {
            target.add(Calendar.DAY_OF_YEAR, 1)
        }
        return target.timeInMillis
    }

    fun canUseExactAlarms(context: Context): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return true
        val alarmManager = context.getSystemService(AlarmManager::class.java) ?: return false
        return alarmManager.canScheduleExactAlarms()
    }

    fun usesExactAlarms(context: Context): Boolean = canUseExactAlarms(context)

    private fun scheduleExactAlarm(context: Context, hour: Int, minute: Int) {
        val alarmManager = context.getSystemService(AlarmManager::class.java) ?: return
        val triggerAt = nextTriggerAt(hour, minute)

        val alarmIntent = Intent(context, DailyReminderAlarmReceiver::class.java).apply {
            action = ACTION_ALARM
            putExtra(EXTRA_HOUR, hour)
            putExtra(EXTRA_MINUTE, minute)
        }
        val alarmPending = PendingIntent.getBroadcast(
            context,
            ALARM_REQUEST_CODE,
            alarmIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val showIntent = PendingIntent.getActivity(
            context,
            0,
            Intent(context, MainActivity::class.java),
            PendingIntent.FLAG_IMMUTABLE,
        )

        alarmManager.setAlarmClock(
            AlarmManager.AlarmClockInfo(triggerAt, showIntent),
            alarmPending,
        )
    }

    private fun cancelExactAlarm(context: Context) {
        val alarmManager = context.getSystemService(AlarmManager::class.java) ?: return
        val alarmIntent = Intent(context, DailyReminderAlarmReceiver::class.java).apply {
            action = ACTION_ALARM
        }
        val pending = PendingIntent.getBroadcast(
            context,
            ALARM_REQUEST_CODE,
            alarmIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        alarmManager.cancel(pending)
    }

    private fun scheduleWorkManagerFallback(context: Context, hour: Int, minute: Int) {
        val delay = (nextTriggerAt(hour, minute) - System.currentTimeMillis()).coerceAtLeast(0L)
        val request = PeriodicWorkRequestBuilder<DailyReminderWorker>(24, TimeUnit.HOURS)
            .setInitialDelay(delay, TimeUnit.MILLISECONDS)
            .build()
        WorkManager.getInstance(context).enqueueUniquePeriodicWork(
            WORK_NAME,
            ExistingPeriodicWorkPolicy.REPLACE,
            request,
        )
    }

    /** Fire the reminder worker immediately (used by the alarm receiver). */
    fun enqueueReminderWork(context: Context) {
        WorkManager.getInstance(context).enqueue(
            OneTimeWorkRequestBuilder<DailyReminderWorker>().build(),
        )
    }
}