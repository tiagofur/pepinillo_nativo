package dev.creapolis.pepinillo.service

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import androidx.hilt.work.HiltWorker
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters
import dagger.assisted.Assisted
import dagger.assisted.AssistedInject
import dev.creapolis.pepinillo.MainActivity
import dev.creapolis.pepinillo.R
import dev.creapolis.pepinillo.data.local.preferences.UserPreferencesRepository
import dev.creapolis.pepinillo.data.repository.SessionRepository
import kotlinx.coroutines.flow.first

@HiltWorker
class DailyReminderWorker @AssistedInject constructor(
    @Assisted private val context: Context,
    @Assisted params: WorkerParameters,
    private val userPreferencesRepository: UserPreferencesRepository,
    private val sessionRepository: SessionRepository,
) : CoroutineWorker(context, params) {

    override suspend fun doWork(): Result {
        val prefs = userPreferencesRepository.preferences.first()
        if (!prefs.dailyReminderEnabled) {
            Log.d(TAG, "Daily reminder disabled in prefs — skipping notification")
            return Result.success()
        }

        if (!NotificationManagerCompat.from(context).areNotificationsEnabled()) {
            Log.w(TAG, "System notifications disabled — skipping daily reminder")
            return Result.success()
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            Log.w(TAG, "POST_NOTIFICATIONS not granted — skipping daily reminder")
            return Result.success()
        }

        val sessionsToday = sessionRepository.getTodayStats().first()?.sessionsCompleted ?: 0
        if (sessionsToday > 0) {
            Log.d(TAG, "User already focused today ($sessionsToday sessions) — skipping reminder")
            rescheduleNext(prefs)
            return Result.success()
        }

        ensureNotificationChannel()
        showReminderNotification()
        rescheduleNext(prefs)
        return Result.success()
    }

    private fun rescheduleNext(prefs: dev.creapolis.pepinillo.data.local.preferences.UserPreferences) {
        if (prefs.dailyReminderEnabled) {
            DailyReminderScheduler.schedule(
                context,
                prefs.dailyReminderHour,
                prefs.dailyReminderMinute,
            )
        }
    }

    private fun ensureNotificationChannel() {
        val channel = NotificationChannel(
            CHANNEL_ID,
            context.getString(R.string.daily_reminder_channel_name),
            NotificationManager.IMPORTANCE_DEFAULT,
        ).apply {
            description = context.getString(R.string.daily_reminder_channel_description)
        }
        context.getSystemService(NotificationManager::class.java)
            .createNotificationChannel(channel)
    }

    private fun showReminderNotification() {
        val intent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        val pendingIntent = PendingIntent.getActivity(
            context,
            0,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle(context.getString(R.string.daily_reminder_title))
            .setContentText(context.getString(R.string.daily_reminder_text))
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .setContentIntent(pendingIntent)
            .setAutoCancel(true)
            .build()

        context.getSystemService(NotificationManager::class.java)
            .notify(NOTIFICATION_ID, notification)
    }

    companion object {
        const val CHANNEL_ID = "daily_reminder_channel"
        private const val NOTIFICATION_ID = 42
        private const val TAG = "DailyReminderWorker"
    }
}
