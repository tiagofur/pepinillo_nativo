package dev.creapolis.pepinillo.service

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * Receives the exact-alarm tick for the daily focus reminder.
 * Enqueues [DailyReminderWorker] and re-arms the next day's alarm.
 */
class DailyReminderAlarmReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != DailyReminderScheduler.ACTION_ALARM) return

        val hour = intent.getIntExtra(DailyReminderScheduler.EXTRA_HOUR, 9)
        val minute = intent.getIntExtra(DailyReminderScheduler.EXTRA_MINUTE, 0)

        Log.d(TAG, "Daily reminder alarm fired at $hour:$minute")
        DailyReminderScheduler.enqueueReminderWork(context)
        // Re-arm for the next local day (nextTriggerAt skips today once the alarm fired).
        DailyReminderScheduler.schedule(context, hour, minute)
    }

    companion object {
        private const val TAG = "DailyReminderAlarm"
    }
}