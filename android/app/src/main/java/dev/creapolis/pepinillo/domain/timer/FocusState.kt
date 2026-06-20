package dev.creapolis.pepinillo.domain.timer

import dev.creapolis.pepinillo.feature.focus.FocusMode
import dev.creapolis.pepinillo.R

/**
 * Represents the current phase within a focus session.
 */
enum class FocusPhase {
    Work,
    ShortBreak,
    LongBreak,
}

/**
 * Immutable snapshot of the focus engine's state.
 */
data class FocusTimerState(
    val mode: FocusMode = FocusMode.Pomodoro,
    val phase: FocusPhase = FocusPhase.Work,
    val status: TimerStatus = TimerStatus.Idle,
    val elapsedMillis: Long = 0L,
    val totalMillis: Long = 25 * 60 * 1000L,
    val completedSessions: Int = 0,
    val linkedTaskId: String? = null,
    val sessionStartTime: Long = 0L,
    val breakSuggested: Boolean = false,
    val midpointTriggered: Boolean = false,
)

enum class TimerStatus {
    Idle,
    Running,
    Paused,
    WaitingForNext,
}

/**
 * Derived display properties from FocusTimerState.
 */
val FocusTimerState.displayTime: String
    get() {
        val remainingMillis = when (mode) {
            // Count-up modes
            FocusMode.Flow, FocusMode.Chrono -> elapsedMillis
            // Count-down modes
            else -> (totalMillis - elapsedMillis).coerceAtLeast(0)
        }
        val totalSeconds = (remainingMillis / 1000).toInt()
        val minutes = totalSeconds / 60
        val seconds = totalSeconds % 60
        return "%02d:%02d".format(minutes, seconds)
    }

val FocusTimerState.progress: Float
    get() = when (mode) {
        FocusMode.Flow, FocusMode.Chrono -> {
            // Count-up: no defined end, pulse at 0 or use elapsed fraction of an hour
            if (elapsedMillis == 0L) 0f
            else (elapsedMillis.toFloat() / (60 * 60 * 1000f)).coerceAtMost(1f)
        }
        else -> {
            // Count-down: 1.0 = full, 0.0 = done
            if (totalMillis == 0L) 1f
            else (1f - (elapsedMillis.toFloat() / totalMillis)).coerceIn(0f, 1f)
        }
    }

val FocusTimerState.phaseLabelRes: Int
    get() = when {
        status == TimerStatus.Idle -> R.string.state_ready
        // WaitingForNext: show the phase that is pending, not "Ready"
        status == TimerStatus.WaitingForNext -> when (phase) {
            FocusPhase.ShortBreak -> R.string.phase_short_break
            FocusPhase.LongBreak -> R.string.phase_long_break
            FocusPhase.Work -> when (mode) {
                // NOTE: phase_focus_numbered is a format string requiring %1$d (session number).
                // Callers MUST pass completedSessions + 1 as the format arg, e.g.
                //   getString(phaseLabelRes, completedSessions + 1)
                FocusMode.Pomodoro -> R.string.phase_focus_numbered
                FocusMode.Flow -> R.string.phase_flowing
                FocusMode.Blocks -> R.string.mode_blocks
                FocusMode.Chrono -> R.string.phase_timing
            }
        }
        phase == FocusPhase.ShortBreak -> R.string.phase_short_break
        phase == FocusPhase.LongBreak -> R.string.phase_long_break
        else -> when (mode) {
            FocusMode.Pomodoro -> R.string.phase_focus_numbered // Format string: callers must pass completedSessions + 1 as %1$d
            FocusMode.Flow -> R.string.phase_flowing
            FocusMode.Blocks -> R.string.mode_blocks
            FocusMode.Chrono -> R.string.phase_timing
        }
    }

val FocusTimerState.isComplete: Boolean
    get() = when (mode) {
        FocusMode.Flow, FocusMode.Chrono -> false // never auto-complete
        else -> elapsedMillis >= totalMillis && status == TimerStatus.Running
    }
