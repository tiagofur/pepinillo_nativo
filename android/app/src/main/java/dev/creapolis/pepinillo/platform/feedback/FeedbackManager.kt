package dev.creapolis.pepinillo.platform.feedback

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import androidx.core.app.NotificationCompat
import dagger.hilt.android.qualifiers.ApplicationContext
import dev.creapolis.pepinillo.MainActivity
import dev.creapolis.pepinillo.R
import dev.creapolis.pepinillo.data.local.preferences.UserPreferencesRepository
import dev.creapolis.pepinillo.domain.timer.FocusPhase
import dev.creapolis.pepinillo.feature.focus.FocusMode
import kotlinx.coroutines.flow.first
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class FeedbackManager @Inject constructor(
    @ApplicationContext private val context: Context,
    private val prefsRepo: UserPreferencesRepository,
) {
    companion object {
        private const val COMPLETION_CHANNEL_ID = "timer_completion_channel"
        private const val COMPLETION_NOTIFICATION_ID = 100
    }

    private val vibrator: Vibrator by lazy {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val manager = context.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager
            manager.defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            context.getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
        }
    }

    private val notificationManager by lazy {
        context.getSystemService(NotificationManager::class.java)
    }

    init {
        createCompletionChannel()
    }

    /**
     * Called when a countdown timer phase completes (Pomodoro work/break, Blocks).
     * Shows a heads-up notification if enabled, otherwise falls back to manual sound/vibration.
     */
    suspend fun onPhaseComplete(mode: FocusMode, phase: FocusPhase) {
        val prefs = prefsRepo.preferences.first()

        if (prefs.timerNotificationsEnabled) {
            showCompletionNotification(mode, phase)
        } else {
            if (prefs.soundEnabled) playCompletionSound()
            if (prefs.vibrationEnabled) vibrate()
        }
    }

    /**
     * Non-completion feedback pulse (flowtime break suggestion, midpoint check-in).
     * Always uses manual sound/vibration — never shows a notification.
     */
    suspend fun onFeedbackPulse() {
        val prefs = prefsRepo.preferences.first()
        if (prefs.soundEnabled) playCompletionSound()
        if (prefs.vibrationEnabled) vibrate()
    }

    private fun showCompletionNotification(mode: FocusMode, phase: FocusPhase) {
        val (title, text) = completionMessage(mode, phase)

        val intent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        val pendingIntent = PendingIntent.getActivity(
            context, 0, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val notification = NotificationCompat.Builder(context, COMPLETION_CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle(title)
            .setContentText(text)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setContentIntent(pendingIntent)
            .setAutoCancel(true)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .build()

        notificationManager.notify(COMPLETION_NOTIFICATION_ID, notification)
    }

    private fun completionMessage(mode: FocusMode, phase: FocusPhase): Pair<String, String> {
        return when {
            mode == FocusMode.Pomodoro && phase == FocusPhase.Work ->
                "Focus session complete!" to "Great work! Time for a break."
            mode == FocusMode.Pomodoro && phase == FocusPhase.ShortBreak ->
                "Break is over!" to "Ready for your next focus session."
            mode == FocusMode.Pomodoro && phase == FocusPhase.LongBreak ->
                "Long break is over!" to "Feeling refreshed? Let's go again."
            mode == FocusMode.Blocks ->
                "Time block complete!" to "Your focused block has finished."
            else ->
                "Timer complete!" to "Your session has finished."
        }
    }

    private fun createCompletionChannel() {
        val channel = NotificationChannel(
            COMPLETION_CHANNEL_ID,
            "Timer Completion",
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "Alerts when a focus timer completes"
            enableVibration(true)
            vibrationPattern = longArrayOf(0, 200, 100, 200)
        }
        notificationManager.createNotificationChannel(channel)
    }

    private fun playCompletionSound() {
        try {
            val uri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
            val ringtone = RingtoneManager.getRingtone(context, uri)
            ringtone?.let {
                it.audioAttributes = AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_NOTIFICATION_EVENT)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build()
                it.play()
            }
        } catch (_: Exception) {
            // Silently fail if no default notification sound available
        }
    }

    private fun vibrate() {
        try {
            if (!vibrator.hasVibrator()) return
            // Double pulse pattern: buzz - pause - buzz
            val effect = VibrationEffect.createWaveform(
                longArrayOf(0, 200, 100, 200),
                -1, // no repeat
            )
            vibrator.vibrate(effect)
        } catch (_: Exception) {
            // Silently fail — vibration is non-critical feedback
        }
    }
}
