package dev.creapolis.pepinillo.domain.soundscape

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.media.MediaPlayer
import android.os.Build
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import dev.creapolis.pepinillo.di.ApplicationScope
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Singleton that manages ambient soundscape playback using Android's [MediaPlayer].
 *
 * Features:
 * - Looping playback from raw resources
 * - AudioFocus management (ducking, pause/resume on focus loss/gain)
 * - Smooth fade-in (1.5s) and fade-out (1.2s)
 * - Real-time volume adjustment
 * - Thread-safe via single-threaded coroutine scope
 */
@Singleton
class SoundscapeManager @Inject constructor(
    @ApplicationContext private val context: Context,
    @ApplicationScope private val scope: CoroutineScope,
) {
    private var mediaPlayer: MediaPlayer? = null
    private var fadeJob: Job? = null

    var currentSoundscape: Soundscape? = null
        private set

    private var targetVolume: Float = 0.5f

    private val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as? AudioManager
    private var focusRequest: AudioFocusRequest? = null

    private val audioFocusChangeListener = AudioManager.OnAudioFocusChangeListener { focusChange ->
        when (focusChange) {
            AudioManager.AUDIOFOCUS_LOSS -> stop()
            AudioManager.AUDIOFOCUS_LOSS_TRANSIENT -> {
                try {
                    mediaPlayer?.pause()
                } catch (_: Exception) {}
            }
            AudioManager.AUDIOFOCUS_LOSS_TRANSIENT_CAN_DUCK -> {
                val ducked = (targetVolume * 0.2f).coerceIn(0f, 1f)
                try {
                    mediaPlayer?.setVolume(ducked, ducked)
                } catch (_: Exception) {}
            }
            AudioManager.AUDIOFOCUS_GAIN -> {
                try {
                    mediaPlayer?.start()
                    mediaPlayer?.setVolume(targetVolume, targetVolume)
                } catch (_: Exception) {}
            }
        }
    }

    companion object {
        private const val FADE_IN_DURATION_MS = 1500L
        private const val FADE_OUT_DURATION_MS = 1200L
        private const val FADE_STEPS = 30
    }

    /**
     * Start playing the given soundscape with a fade-in.
     * If the same soundscape is already playing, only the volume is updated.
     */
    fun play(soundscape: Soundscape, volume: Float) {
        if (soundscape == currentSoundscape) {
            setVolume(volume)
            return
        }

        // Stop current playback immediately (no fade for switch)
        stopInternal()

        targetVolume = volume.coerceIn(0f, 1f)

        if (!requestAudioFocus()) {
            return
        }

        try {
            val player = MediaPlayer().apply {
                setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_MEDIA)
                        .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                        .build()
                )
                val afd = context.resources.openRawResourceFd(soundscape.rawResId) ?: return
                setDataSource(afd.fileDescriptor, afd.startOffset, afd.length)
                afd.close()
                isLooping = true
                setVolume(0f, 0f) // Start silent for fade-in
                prepare()
                start()
            }

            mediaPlayer = player
            currentSoundscape = soundscape

            // Fade in
            fadeJob?.cancel()
            fadeJob = scope.launch {
                fadeVolumeTo(0f, targetVolume, FADE_IN_DURATION_MS)
            }
        } catch (e: Exception) {
            stopInternal()
        }
    }

    /**
     * Stop playback immediately without fade.
     */
    fun stop() {
        fadeJob?.cancel()
        stopInternal()
    }

    /**
     * Fade out over 1.2s, then stop.
     */
    fun fadeOut() {
        val player = mediaPlayer ?: return
        fadeJob?.cancel()
        fadeJob = scope.launch {
            fadeVolumeTo(targetVolume, 0f, FADE_OUT_DURATION_MS)
            stopInternal()
        }
    }

    /**
     * Adjust volume in real-time (0.0 - 1.0).
     */
    fun setVolume(volume: Float) {
        targetVolume = volume.coerceIn(0f, 1f)
        mediaPlayer?.setVolume(targetVolume, targetVolume)
    }

    /**
     * Play a 3-second preview of a soundscape, then fade out.
     */
    fun preview(soundscape: Soundscape) {
        play(soundscape, 0.5f)
        fadeJob?.cancel()
        fadeJob = scope.launch {
            delay(3000L)
            fadeVolumeTo(targetVolume, 0f, FADE_OUT_DURATION_MS)
            stopInternal()
        }
    }

    private fun requestAudioFocus(): Boolean {
        val am = audioManager ?: return true
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val req = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK)
                .setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_MEDIA)
                        .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                        .build()
                )
                .setOnAudioFocusChangeListener(audioFocusChangeListener)
                .build()
            focusRequest = req
            am.requestAudioFocus(req) == AudioManager.AUDIOFOCUS_REQUEST_GRANTED
        } else {
            @Suppress("DEPRECATION")
            am.requestAudioFocus(
                audioFocusChangeListener,
                AudioManager.STREAM_MUSIC,
                AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK
            ) == AudioManager.AUDIOFOCUS_REQUEST_GRANTED
        }
    }

    private fun abandonAudioFocus() {
        val am = audioManager ?: return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            focusRequest?.let { am.abandonAudioFocusRequest(it) }
            focusRequest = null
        } else {
            @Suppress("DEPRECATION")
            am.abandonAudioFocus(audioFocusChangeListener)
        }
    }

    private fun stopInternal() {
        abandonAudioFocus()
        try {
            mediaPlayer?.stop()
            mediaPlayer?.release()
        } catch (_: Exception) {
            // Ignore — player may already be released
        }
        mediaPlayer = null
        currentSoundscape = null
    }

    private suspend fun fadeVolumeTo(from: Float, to: Float, durationMs: Long) {
        val stepDuration = durationMs / FADE_STEPS
        for (i in 0..FADE_STEPS) {
            val t = i.toFloat() / FADE_STEPS
            val volume = from + (to - from) * t
            val clamped = volume.coerceIn(0f, 1f)
            mediaPlayer?.setVolume(clamped, clamped)
            delay(stepDuration)
        }
        if (to > 0f) {
            targetVolume = to
        }
    }
}
