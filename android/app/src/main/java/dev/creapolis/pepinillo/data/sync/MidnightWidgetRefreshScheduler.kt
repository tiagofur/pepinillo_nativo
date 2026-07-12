package dev.creapolis.pepinillo.data.sync

import android.content.Context
import androidx.work.ExistingWorkPolicy
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager
import java.util.Calendar
import java.util.concurrent.TimeUnit

/**
 * Schedules a one-shot [WidgetRefreshWorker] at the next local midnight so stats widgets
 * roll over to the new day without waiting for the 15-minute periodic refresh.
 */
object MidnightWidgetRefreshScheduler {

    private const val WORK_NAME = "widget_midnight_refresh"

    fun schedule(context: Context) {
        val delay = millisUntilNextMidnight()
        val request = OneTimeWorkRequestBuilder<WidgetRefreshWorker>()
            .setInitialDelay(delay, TimeUnit.MILLISECONDS)
            .addTag("midnight_refresh")
            .build()
        WorkManager.getInstance(context).enqueueUniqueWork(
            WORK_NAME,
            ExistingWorkPolicy.REPLACE,
            request,
        )
    }

    fun millisUntilNextMidnight(now: Calendar = Calendar.getInstance()): Long {
        val nextMidnight = (now.clone() as Calendar).apply {
            add(Calendar.DAY_OF_YEAR, 1)
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }
        return (nextMidnight.timeInMillis - now.timeInMillis).coerceAtLeast(0L)
    }
}