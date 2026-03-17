package dev.creapolis.pepinillo.platform.feedback

import android.content.Context
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import dagger.hilt.android.qualifiers.ApplicationContext
import dev.creapolis.pepinillo.data.local.preferences.UserPreferencesRepository
import kotlinx.coroutines.flow.first
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class FeedbackManager @Inject constructor(
    @ApplicationContext private val context: Context,
    private val prefsRepo: UserPreferencesRepository,
) {
    private val vibrator: Vibrator by lazy {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val manager = context.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager
            manager.defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            context.getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
        }
    }

    suspend fun onPhaseComplete() {
        val prefs = prefsRepo.preferences.first()

        if (prefs.soundEnabled) {
            playCompletionSound()
        }
        if (prefs.vibrationEnabled) {
            vibrate()
        }
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
        if (!vibrator.hasVibrator()) return
        // Double pulse pattern: buzz - pause - buzz
        val effect = VibrationEffect.createWaveform(
            longArrayOf(0, 200, 100, 200),
            -1, // no repeat
        )
        vibrator.vibrate(effect)
    }
}
