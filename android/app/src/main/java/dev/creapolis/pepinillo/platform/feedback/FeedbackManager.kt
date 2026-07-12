package dev.creapolis.pepinillo.platform.feedback

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
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

    suspend fun onPhaseComplete(mode: FocusMode, phase: FocusPhase) {
        val prefs = prefsRepo.preferences.first()

        // Sound and haptics are always applied when enabled — notifications are additive.
        if (prefs.soundEnabled) playCompletionSound()
        if (prefs.vibrationEnabled) vibrate()

        if (prefs.timerNotificationsEnabled && canPostNotifications()) {
            showCompletionNotification(mode, phase)
        }
    }

    private fun canPostNotifications(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return true
        return ContextCompat.checkSelfPermission(
            context,
            Manifest.permission.POST_NOTIFICATIONS,
        ) == PackageManager.PERMISSION_GRANTED
    }

    suspend fun onFeedbackPulse() {
        val prefs = prefsRepo.preferences.first()
        if (prefs.soundEnabled) playCompletionSound()
        if (prefs.vibrationEnabled) vibrate()
    }

    private fun showCompletionNotification(mode: FocusMode, phase: FocusPhase) {
        val (titleRes, textRes) = completionMessageRes(mode, phase)
        val title = context.getString(titleRes)
        val text = context.getString(textRes)

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
            .build()

        notificationManager?.notify(COMPLETION_NOTIFICATION_ID, notification)
    }

    private fun completionMessageRes(mode: FocusMode, phase: FocusPhase): Pair<Int, Int> {
        return when {
            mode == FocusMode.Pomodoro && phase == FocusPhase.Work ->
                R.string.msg_focus_complete_title to R.string.msg_focus_complete_text
            mode == FocusMode.Pomodoro && phase == FocusPhase.ShortBreak ->
                R.string.msg_short_break_over_title to R.string.msg_short_break_over_text
            mode == FocusMode.Pomodoro && phase == FocusPhase.LongBreak ->
                R.string.msg_long_break_over_title to R.string.msg_long_break_over_text
            mode == FocusMode.Blocks ->
                R.string.msg_block_complete_title to R.string.msg_block_complete_text
            else ->
                R.string.msg_timer_complete_title to R.string.msg_timer_complete_text
        }
    }

    private fun createCompletionChannel() {
        val channel = NotificationChannel(
            COMPLETION_CHANNEL_ID,
            context.getString(R.string.notification_completion_channel_name),
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = context.getString(R.string.notification_completion_channel_desc)
            enableVibration(true)
            vibrationPattern = longArrayOf(0, 200, 100, 200)
        }
        notificationManager?.createNotificationChannel(channel)
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
            // Silently fail
        }
    }

    private fun vibrate() {
        try {
            if (!vibrator.hasVibrator()) return
            
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                val composition = VibrationEffect.startComposition()
                    .addPrimitive(VibrationEffect.Composition.PRIMITIVE_CLICK)
                    .addPrimitive(VibrationEffect.Composition.PRIMITIVE_TICK, 0.5f, 50)
                    .addPrimitive(VibrationEffect.Composition.PRIMITIVE_CLICK)
                    .compose()
                vibrator.vibrate(composition)
            } else {
                val effect = VibrationEffect.createWaveform(
                    longArrayOf(0, 200, 100, 200),
                    -1,
                )
                vibrator.vibrate(effect)
            }
        } catch (_: Exception) {
            // Silently fail
        }
    }
}
