package dev.creapolis.pepinillo.data

import java.util.Locale

/**
 * Local tick helper for the wear timer UI. Derives display time and progress from
 * epoch anchors pushed by the phone (or set optimistically by [dev.creapolis.pepinillo.viewmodel.WearViewModel])
 * so countdown and count-up modes tick independently between syncs.
 */
object WearTimerDisplay {

    data class TickResult(
        val displayTime: String,
        val progress: Float,
    )

    fun isCountUpMode(mode: String): Boolean = mode == "Flow" || mode == "Chrono"

    fun tick(state: WearTimerState, nowMs: Long = System.currentTimeMillis()): TickResult {
        if (state.status == "Paused") {
            return TickResult(state.displayTime, state.progress)
        }
        if (state.status != "Running") {
            return TickResult(state.displayTime, state.progress)
        }

        return if (isCountUpMode(state.mode)) {
            tickCountUp(state, nowMs)
        } else {
            tickCountDown(state, nowMs)
        }
    }

    private fun tickCountUp(state: WearTimerState, nowMs: Long): TickResult {
        if (state.phaseStartEpochMs <= 0L) {
            return TickResult(state.displayTime, state.progress)
        }
        val elapsed = (nowMs - state.phaseStartEpochMs).coerceAtLeast(0L)
        val progress = if (elapsed == 0L) {
            0f
        } else {
            (elapsed.toFloat() / (60 * 60 * 1000f)).coerceAtMost(1f)
        }
        return TickResult(formatMillis(elapsed, ceilSeconds = false), progress)
    }

    private fun tickCountDown(state: WearTimerState, nowMs: Long): TickResult {
        if (state.phaseEndEpochMs <= 0L || state.totalDurationMs <= 0L) {
            return TickResult(state.displayTime, state.progress)
        }
        val remaining = (state.phaseEndEpochMs - nowMs).coerceAtLeast(0L)
        val progress = (1f - (remaining.toFloat() / state.totalDurationMs)).coerceIn(0f, 1f)
        return TickResult(formatMillis(remaining, ceilSeconds = true), progress)
    }

    /** Formats millis as mm:ss. Countdown uses ceiling seconds; count-up uses floor. */
    fun formatMillis(millis: Long, ceilSeconds: Boolean): String {
        val totalSeconds = if (ceilSeconds) {
            (millis + 999) / 1000
        } else {
            millis / 1000
        }
        val minutes = totalSeconds / 60
        val seconds = totalSeconds % 60
        return String.format(Locale.US, "%02d:%02d", minutes, seconds)
    }
}