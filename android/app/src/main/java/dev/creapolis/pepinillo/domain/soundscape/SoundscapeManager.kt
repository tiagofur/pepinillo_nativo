package dev.creapolis.pepinillo.domain.soundscape

import android.content.Context
import android.media.AudioAttributes
import android.media.MediaPlayer
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
 * - Smooth fade-in (1.5s) and fade-out (1.2s)
 * - Real-time volume adjustment
 * - Thread-safe via single-threaded coroutine scope
 */
@Singleton
class SoundscapeManager @Inject constructor(
    @param:ApplicationContext private val context: Context,
    @param:ApplicationScope private val scope: CoroutineScope,
) {
    private var mediaPlayer: MediaPlayer? = null
    private var fadeJob: Job? = null

    var currentSoundscape: Soundscape? = null
        private set

    private var targetVolume: Float = 0.5f

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

    private fun stopInternal() {
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
