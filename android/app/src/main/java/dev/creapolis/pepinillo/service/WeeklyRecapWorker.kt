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
import dev.creapolis.pepinillo.navigation.TopLevelDestination
import kotlinx.coroutines.flow.first

/**
 * Weekly focus recap notification (default Sunday 18:00 local). Summarises the week's
 * work-session minutes and count — the same calculation the Dashboard weekly report uses
 * (raw sessions, breaks excluded) — and deep-links to the Dashboard (#730). The Dashboard
 * is the destination, not WeeklyReviewSheet, because the review sheet sits behind the
 * Pro paywall and a recap notification must never open a paywall.
 */
@HiltWorker
class WeeklyRecapWorker @AssistedInject constructor(
    @Assisted private val context: Context,
    @Assisted params: WorkerParameters,
    private val userPreferencesRepository: UserPreferencesRepository,
    private val sessionRepository: SessionRepository,
) : CoroutineWorker(context, params) {

    override suspend fun doWork(): Result {
        val prefs = userPreferencesRepository.preferences.first()
        if (!prefs.weeklyRecapEnabled) {
            Log.d(TAG, "Weekly recap disabled in prefs — skipping")
            return Result.success()
        }

        val now = System.currentTimeMillis()
        if (now - prefs.weeklyRecapLastSentAt < MIN_RESEND_INTERVAL_MS) {
            Log.d(TAG, "Recap sent within the last 6 days — skipping duplicate dispatch")
            rescheduleNext(prefs)
            return Result.success()
        }

        if (!canPostNotifications()) {
            Log.w(TAG, "Notifications unavailable — skipping weekly recap")
            rescheduleNext(prefs)
            return Result.success()
        }

        val week = sessionRepository.getWeekSessions().first()
            .filter { it.phase == null || it.phase == "Work" }
        val minutes = (week.sumOf { it.durationMillis } / 60_000).toInt()

        ensureNotificationChannel()
        showRecapNotification(minutes, week.size)
        userPreferencesRepository.updateWeeklyRecapLastSentAt(now)
        rescheduleNext(prefs)
        return Result.success()
    }

    private suspend fun rescheduleNext(prefs: dev.creapolis.pepinillo.data.local.preferences.UserPreferences) {
        if (prefs.weeklyRecapEnabled) {
            WeeklyRecapScheduler.schedule(
                context,
                prefs.weeklyRecapDayOfWeek,
                prefs.weeklyRecapHour,
                prefs.weeklyRecapMinute,
            )
        }
    }

    private fun canPostNotifications(): Boolean {
        if (!NotificationManagerCompat.from(context).areNotificationsEnabled()) return false
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) ==
                PackageManager.PERMISSION_GRANTED
        } else {
            true
        }
    }

    private fun ensureNotificationChannel() {
        val channel = NotificationChannel(
            CHANNEL_ID,
            context.getString(R.string.weekly_recap_channel_name),
            NotificationManager.IMPORTANCE_DEFAULT,
        ).apply {
            description = context.getString(R.string.weekly_recap_channel_desc)
        }
        context.getSystemService(NotificationManager::class.java)
            .createNotificationChannel(channel)
    }

    private fun showRecapNotification(minutes: Int, sessionCount: Int) {
        val intent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP
            putExtra(MainActivity.EXTRA_NAV_ROUTE, TopLevelDestination.Dashboard.route)
        }
        val pendingIntent = PendingIntent.getActivity(
            context,
            0,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val sessionsPhrase = context.resources.getQuantityString(
            R.plurals.weekly_recap_sessions_count,
            sessionCount,
            sessionCount,
        )
        val text = if (minutes > 0) {
            context.getString(R.string.weekly_recap_text, formatDuration(minutes), sessionsPhrase)
        } else {
            context.getString(R.string.weekly_recap_text_empty)
        }

        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle(context.getString(R.string.weekly_recap_title))
            .setContentText(text)
            .setStyle(NotificationCompat.BigTextStyle().bigText(text))
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .setContentIntent(pendingIntent)
            .setAutoCancel(true)
            .build()

        context.getSystemService(NotificationManager::class.java)
            .notify(NOTIFICATION_ID, notification)
    }

    /** "Xh Ym" / "Xh" / "Ym" — same compact format as the profile stats screen. */
    private fun formatDuration(totalMinutes: Int): String {
        val hours = totalMinutes / 60
        val minutes = totalMinutes % 60
        return when {
            hours > 0 && minutes > 0 -> "${hours}h ${minutes}m"
            hours > 0 -> "${hours}h"
            else -> "${minutes}m"
        }
    }

    companion object {
        const val CHANNEL_ID = "weekly_recap_channel"
        private const val NOTIFICATION_ID = 43
        private const val TAG = "WeeklyRecapWorker"

        /** Guards against WorkManager retry double-dispatch (spec: < 6 days). */
        const val MIN_RESEND_INTERVAL_MS = 6L * 24 * 60 * 60 * 1000
    }
}
