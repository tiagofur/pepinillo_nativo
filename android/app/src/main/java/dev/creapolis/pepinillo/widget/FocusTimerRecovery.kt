package dev.creapolis.pepinillo.widget

import android.content.Context
import android.content.Intent
import android.util.Log
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

    private const val TAG = "FocusTimerRecovery"

    suspend fun restoreOnLaunch(context: Context) {
        val recovery = FocusTimerService.readRecoveryState(context)
        if (recovery != null) {
            try {
                context.startForegroundService(
                    Intent(context, FocusTimerService::class.java).apply {
                        action = FocusTimerService.ACTION_RECOVER
                    },
                )
            } catch (e: Exception) {
                // D2: this runs from Application.onCreate / BOOT_COMPLETED, and Android can
                // respawn the process in the background (e.g. via WorkManager). There,
                // starting a foreground service throws
                // ForegroundServiceStartNotAllowedException (API 31+) — unguarded, that
                // crash-loops the freshly respawned process. Recover the same way we do
                // for an absent recovery state: log, drop the stale recovery prefs and
                // reset the widget to idle.
                Log.e(TAG, "Could not start focus timer service on launch — clearing stale state", e)
                clearStaleWidgetState(context)
            }
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