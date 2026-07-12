package dev.creapolis.pepinillo.widget

import android.content.Context
import android.content.Intent
import androidx.glance.appwidget.GlanceAppWidgetManager
import androidx.glance.appwidget.updateAll
import androidx.glance.appwidget.state.getAppWidgetState
import androidx.glance.appwidget.state.updateAppWidgetState
import androidx.glance.state.PreferencesGlanceStateDefinition
import dev.creapolis.pepinillo.domain.timer.TimerStatus
import dev.creapolis.pepinillo.feature.focus.FocusMode
import dev.creapolis.pepinillo.service.FocusTimerService

/**
 * Restores an active focus session after cold start / reboot, or clears stale widget state
 * when recovery prefs are absent (zombie Running widget after force-stop).
 */
object FocusTimerRecovery {

    suspend fun restoreOnLaunch(context: Context) {
        val recovery = FocusTimerService.readRecoveryState(context)
        if (recovery != null) {
            context.startForegroundService(
                Intent(context, FocusTimerService::class.java).apply {
                    action = FocusTimerService.ACTION_RECOVER
                },
            )
        } else {
            clearStaleWidgetState(context)
        }
    }

    suspend fun clearStaleWidgetState(context: Context) {
        FocusTimerService.clearRecoveryState(context)
        val manager = GlanceAppWidgetManager(context)
        val glanceIds = manager.getGlanceIds(FocusTimerWidget::class.java)
        glanceIds.forEach { glanceId ->
            val prefs = getAppWidgetState(context, PreferencesGlanceStateDefinition, glanceId)
            val modeName = prefs[FocusTimerWidgetKeys.MODE] ?: FocusMode.Pomodoro.name
            val mode = FocusMode.entries.find { it.name == modeName } ?: FocusMode.Pomodoro
            val selectedModeName = prefs[FocusTimerWidgetKeys.SELECTED_MODE] ?: mode.name
            val selectedMode = FocusMode.entries.find { it.name == selectedModeName } ?: mode
            updateAppWidgetState(context, PreferencesGlanceStateDefinition, glanceId) { stored ->
                stored.toMutablePreferences().apply {
                    this[FocusTimerWidgetKeys.MODE] = mode.name
                    this[FocusTimerWidgetKeys.SELECTED_MODE] = selectedMode.name
                    this[FocusTimerWidgetKeys.DISPLAY] = selectedMode.defaultDisplayTime
                    this[FocusTimerWidgetKeys.PHASE] = context.getString(mode.labelRes)
                    this[FocusTimerWidgetKeys.STATUS] = TimerStatus.Idle.name
                    this[FocusTimerWidgetKeys.PROGRESS] = 1f
                    remove(FocusTimerWidgetKeys.FINISH_TIMESTAMP)
                    remove(FocusTimerWidgetKeys.LINKED_TASK)
                    remove(FocusTimerWidgetKeys.LINKED_TASK_TITLE)
                }
            }
        }
        if (glanceIds.isNotEmpty()) {
            FocusTimerWidget().updateAll(context)
        }
    }
}