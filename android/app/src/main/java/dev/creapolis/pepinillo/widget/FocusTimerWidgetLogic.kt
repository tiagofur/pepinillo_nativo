package dev.creapolis.pepinillo.widget

import dev.creapolis.pepinillo.domain.timer.TimerStatus
import dev.creapolis.pepinillo.service.FocusTimerService

/**
 * Pure helpers for focus-timer widget control logic (unit-testable).
 */
object FocusTimerWidgetLogic {

    fun isActiveSession(status: TimerStatus): Boolean =
        status == TimerStatus.Running ||
            status == TimerStatus.Paused ||
            status == TimerStatus.WaitingForNext

    /**
     * Service action for the primary play/pause control.
     * WaitingForNext uses RESUME (same as in-app) — not START_MODE.
     */
    fun primaryControlAction(status: TimerStatus): String = when (status) {
        TimerStatus.Running -> FocusTimerService.ACTION_PAUSE
        TimerStatus.Paused, TimerStatus.WaitingForNext -> FocusTimerService.ACTION_RESUME
        TimerStatus.Idle -> FocusTimerService.ACTION_START_MODE
    }

    /** Progress ring / widget refresh throttle while the countdown is live. */
    fun widgetUpdateThrottleMs(status: TimerStatus): Long =
        if (status == TimerStatus.Running) 1_000L else 30_000L
}