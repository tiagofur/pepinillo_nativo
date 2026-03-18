package dev.creapolis.pepinillo.domain.timer

import dev.creapolis.pepinillo.feature.focus.FocusMode

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

val FocusTimerState.phaseLabel: String
    get() = when {
        status == TimerStatus.Idle -> when (mode) {
            FocusMode.Pomodoro -> "Focus"
            FocusMode.Flow -> "Flow"
            FocusMode.Blocks -> "Block"
            FocusMode.Chrono -> "Stopwatch"
        }
        phase == FocusPhase.ShortBreak -> "Short Break"
        phase == FocusPhase.LongBreak -> "Long Break"
        else -> when (mode) {
            FocusMode.Pomodoro -> "Focus ${completedSessions + 1}"
            FocusMode.Flow -> "Flowing..."
            FocusMode.Blocks -> "Block"
            FocusMode.Chrono -> "Timing..."
        }
    }

val FocusTimerState.isComplete: Boolean
    get() = when (mode) {
        FocusMode.Flow, FocusMode.Chrono -> false // never auto-complete
        else -> elapsedMillis >= totalMillis && status == TimerStatus.Running
    }
