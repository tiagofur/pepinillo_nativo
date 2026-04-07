package dev.creapolis.pepinillo.widget

import android.content.Context
import android.content.Intent
import androidx.compose.runtime.Composable
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.floatPreferencesKey
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.GlanceTheme
import androidx.glance.action.ActionParameters
import androidx.glance.action.actionParametersOf
import androidx.glance.action.actionStartActivity
import androidx.glance.action.clickable
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.GlanceAppWidgetManager
import androidx.glance.appwidget.GlanceAppWidgetReceiver
import androidx.glance.appwidget.action.ActionCallback
import androidx.glance.appwidget.action.actionRunCallback
import androidx.glance.appwidget.cornerRadius
import androidx.glance.appwidget.provideContent
import androidx.glance.appwidget.state.updateAppWidgetState
import androidx.glance.appwidget.updateAll
import androidx.glance.background
import androidx.glance.currentState
import androidx.glance.layout.Alignment
import androidx.glance.layout.Box
import androidx.glance.layout.Column
import androidx.glance.layout.Row
import androidx.glance.layout.Spacer
import androidx.glance.layout.fillMaxSize
import androidx.glance.layout.fillMaxWidth
import androidx.glance.layout.height
import androidx.glance.layout.padding
import androidx.glance.layout.width
import androidx.glance.state.PreferencesGlanceStateDefinition
import androidx.glance.text.FontWeight
import androidx.glance.text.Text
import androidx.glance.text.TextAlign
import androidx.glance.text.TextStyle
import androidx.glance.unit.ColorProvider
import dev.creapolis.pepinillo.MainActivity
import dev.creapolis.pepinillo.R
import dev.creapolis.pepinillo.domain.timer.TimerStatus
import dev.creapolis.pepinillo.feature.focus.FocusMode
import dev.creapolis.pepinillo.service.FocusTimerService
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

import androidx.glance.appwidget.action.ToggleableStateKey
import dagger.hilt.android.EntryPointAccessors
import dev.creapolis.pepinillo.core.billing.SubscriptionManager

class FocusTimerWidget : GlanceAppWidget() {
    override val stateDefinition = PreferencesGlanceStateDefinition

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        // Fetch fresh subscription status
        try {
            val entryPoint = EntryPointAccessors.fromApplication(
                context.applicationContext, WidgetEntryPoint::class.java,
            )
            val isPro = entryPoint.subscriptionManager().subscriptionState.value.isPro
            updateAppWidgetState(context, PreferencesGlanceStateDefinition, id) { prefs ->
                prefs.toMutablePreferences().apply {
                    this[PREF_IS_PRO] = isPro
                }
            }
        } catch (e: Exception) {
            // Ignore
        }

        provideContent {
            GlanceTheme {
                val prefs = currentState<Preferences>()
                val state = prefsToTimerState(prefs)
                when (state.status) {
                    TimerStatus.Running, TimerStatus.Paused -> RunningWidget(context, state)
                    else -> if (state.selectedMode != null) ReadyWidget(context, state) else IdleWidget(context, state)
                }
            }
        }
    }
}

data class TimerWidgetState(
    val mode: FocusMode = FocusMode.Pomodoro,
    val selectedMode: FocusMode? = null,
    val displayTime: String = "25:00",
    val finishTimestamp: Long? = null,
    val phaseLabel: String = "Focus",
    val status: TimerStatus = TimerStatus.Idle,
    val progress: Float = 1f,
    val linkedTaskName: String? = null,
    val isPro: Boolean = false,
)

// Glance DataStore preference keys
private val PREF_MODE = stringPreferencesKey("widget_mode")
private val PREF_SELECTED_MODE = stringPreferencesKey("widget_selected_mode")
private val PREF_DISPLAY = stringPreferencesKey("widget_display")
private val PREF_FINISH_TIMESTAMP = androidx.datastore.preferences.core.longPreferencesKey("widget_finish_timestamp")
private val PREF_PHASE = stringPreferencesKey("widget_phase")
private val PREF_STATUS = stringPreferencesKey("widget_status")
private val PREF_PROGRESS = floatPreferencesKey("widget_progress")
private val PREF_LINKED_TASK = stringPreferencesKey("widget_linked_task")
private val PREF_IS_PRO = androidx.datastore.preferences.core.booleanPreferencesKey("is_pro")

private fun prefsToTimerState(prefs: Preferences): TimerWidgetState {
    val modeName = prefs[PREF_MODE] ?: FocusMode.Pomodoro.name
    val selectedModeName = prefs[PREF_SELECTED_MODE]
    val mode = FocusMode.entries.find { it.name == modeName } ?: FocusMode.Pomodoro
    val selectedMode = selectedModeName?.let { name -> FocusMode.entries.find { it.name == name } }
    val statusName = prefs[PREF_STATUS] ?: TimerStatus.Idle.name
    val status = TimerStatus.entries.find { it.name == statusName } ?: TimerStatus.Idle

    return TimerWidgetState(
        mode = mode,
        selectedMode = selectedMode,
        displayTime = prefs[PREF_DISPLAY] ?: mode.defaultDisplayTime,
        finishTimestamp = prefs[PREF_FINISH_TIMESTAMP],
        phaseLabel = prefs[PREF_PHASE] ?: mode.label,
        status = status,
        progress = prefs[PREF_PROGRESS] ?: 1f,
        linkedTaskName = prefs[PREF_LINKED_TASK],
        isPro = prefs[PREF_IS_PRO] ?: false,
    )
}

suspend fun updateWidgetState(context: Context, state: TimerWidgetState) {
    val manager = GlanceAppWidgetManager(context)
    val glanceIds = manager.getGlanceIds(FocusTimerWidget::class.java)
    glanceIds.forEach { glanceId ->
        updateAppWidgetState(context, PreferencesGlanceStateDefinition, glanceId) { prefs ->
            prefs.toMutablePreferences().apply {
                this[PREF_MODE] = state.mode.name
                if (state.selectedMode != null) {
                    this[PREF_SELECTED_MODE] = state.selectedMode.name
                } else {
                    remove(PREF_SELECTED_MODE)
                }
                this[PREF_DISPLAY] = state.displayTime
                if (state.finishTimestamp != null) {
                    this[PREF_FINISH_TIMESTAMP] = state.finishTimestamp
                } else {
                    remove(PREF_FINISH_TIMESTAMP)
                }
                this[PREF_PHASE] = state.phaseLabel
                this[PREF_STATUS] = state.status.name
                this[PREF_PROGRESS] = state.progress
                if (state.linkedTaskName != null) {
                    this[PREF_LINKED_TASK] = state.linkedTaskName
                } else {
                    remove(PREF_LINKED_TASK)
                }
            }
        }
    }
}

fun modeColor(mode: FocusMode): ColorProvider {
    return when (mode) {
        FocusMode.Pomodoro -> ColorProvider(R.color.widget_pomodoro)
        FocusMode.Flow -> ColorProvider(R.color.widget_flow)
        FocusMode.Blocks -> ColorProvider(R.color.widget_blocks)
        FocusMode.Chrono -> ColorProvider(R.color.widget_chrono)
    }
}

@Composable
private fun IdleWidget(context: Context, state: TimerWidgetState) {
    Column(
        modifier = GlanceModifier
            .fillMaxSize()
            .background(GlanceTheme.colors.widgetBackground)
            .cornerRadius(24.dp)
            .padding(12.dp)
            .clickable(actionStartActivity<MainActivity>()),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            text = "Tap to select mode",
            style = TextStyle(
                fontSize = 11.sp,
                color = GlanceTheme.colors.onSurfaceVariant,
                textAlign = TextAlign.Center,
            ),
        )
        Spacer(modifier = GlanceModifier.height(8.dp))
        ModeSelectorRow(context, selectedMode = null, isPro = state.isPro)
    }
}

@Composable
private fun ReadyWidget(context: Context, state: TimerWidgetState) {
    Column(
        modifier = GlanceModifier
            .fillMaxSize()
            .background(GlanceTheme.colors.widgetBackground)
            .cornerRadius(24.dp)
            .padding(12.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        val mode = state.selectedMode ?: state.mode
        val color = modeColor(mode)

        Text(
            text = mode.label,
            style = TextStyle(
                fontSize = 12.sp,
                fontWeight = FontWeight.Medium,
                color = color,
            ),
        )
        Text(
            text = state.displayTime,
            style = TextStyle(
                fontWeight = FontWeight.Bold,
                fontSize = 36.sp,
                color = GlanceTheme.colors.onSurface,
                textAlign = TextAlign.Center,
            ),
        )
        Spacer(modifier = GlanceModifier.height(6.dp))
        ModeSelectorRow(context, selectedMode = state.selectedMode, isPro = state.isPro)
        Spacer(modifier = GlanceModifier.height(8.dp))
        Box(
            modifier = GlanceModifier
                .fillMaxWidth()
                .background(color)
                .cornerRadius(20.dp)
                .clickable(actionRunCallback<StartAction>(
                    actionParametersOf(modeParam to mode.name),
                ))
                .padding(vertical = 10.dp),
            contentAlignment = Alignment.Center,
        ) {
            Text(
                text = "\u25B6  Start Focus",
                style = TextStyle(
                    fontSize = 14.sp,
                    fontWeight = FontWeight.Bold,
                    color = ColorProvider(R.color.widget_white),
                ),
            )
        }
    }
}

import java.time.Instant
import androidx.glance.text.TextRelativeTimeFormat

@Composable
private fun RunningWidget(context: Context, state: TimerWidgetState) {
    Column(
        modifier = GlanceModifier
            .fillMaxSize()
            .background(GlanceTheme.colors.widgetBackground)
            .cornerRadius(24.dp)
            .padding(14.dp)
            .clickable(actionStartActivity<MainActivity>()),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        val mode = state.mode
        val color = modeColor(mode)
        val isRunning = state.status == TimerStatus.Running

        Text(
            text = "${mode.label} \u2022 ${state.phaseLabel}",
            style = TextStyle(
                fontSize = 12.sp,
                fontWeight = FontWeight.Medium,
                color = color,
            ),
        )
        Spacer(modifier = GlanceModifier.height(2.dp))
        
        if (isRunning && state.finishTimestamp != null) {
            // Native system-handled countdown (Battery efficient!)
            Text(
                text = Instant.ofEpochMilli(state.finishTimestamp),
                format = TextRelativeTimeFormat.Countdown,
                style = TextStyle(
                    fontWeight = FontWeight.Bold,
                    fontSize = 36.sp,
                    color = color,
                    textAlign = TextAlign.Center,
                ),
            )
        } else {
            // Static display when paused
            Text(
                text = state.displayTime,
                style = TextStyle(
                    fontWeight = FontWeight.Bold,
                    fontSize = 36.sp,
                    color = color,
                    textAlign = TextAlign.Center,
                ),
            )
        }

        // Show linked task name
        if (!state.linkedTaskName.isNullOrBlank()) {
            Text(
                text = "\uD83D\uDD17 ${state.linkedTaskName}",
                style = TextStyle(
                    fontSize = 11.sp,
                    color = GlanceTheme.colors.onSurfaceVariant,
                    textAlign = TextAlign.Center,
                ),
                maxLines = 1,
            )
        }
        Spacer(modifier = GlanceModifier.height(8.dp))
        Row(
            modifier = GlanceModifier.fillMaxWidth(),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Box(
                modifier = GlanceModifier
                    .background(color)
                    .cornerRadius(20.dp)
                    .clickable(
                        if (isRunning) actionRunCallback<PauseAction>()
                        else actionRunCallback<ResumeAction>(),
                    )
                    .padding(horizontal = 24.dp, vertical = 10.dp),
                contentAlignment = Alignment.Center,
            ) {
                Text(
                    text = if (isRunning) "\u23F8  Pause" else "\u25B6  Resume",
                    style = TextStyle(fontSize = 14.sp, fontWeight = FontWeight.Bold, color = ColorProvider(R.color.widget_white)),
                )
            }
            Spacer(modifier = GlanceModifier.width(8.dp))
            Box(
                modifier = GlanceModifier
                    .background(ColorProvider(R.color.widget_stop_bg))
                    .cornerRadius(20.dp)
                    .clickable(actionRunCallback<StopAction>())
                    .padding(horizontal = 24.dp, vertical = 10.dp),
                contentAlignment = Alignment.Center,
            ) {
                Text(
                    text = "\u23F9  Stop",
                    style = TextStyle(fontSize = 14.sp, fontWeight = FontWeight.Bold, color = ColorProvider(R.color.widget_stop_text)),
                )
            }
        }
    }
}

@Composable
private fun ModeSelectorRow(context: Context, selectedMode: FocusMode?, isPro: Boolean) {
    Row(
        modifier = GlanceModifier.fillMaxWidth(),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        ModeChip(context, FocusMode.Pomodoro, "Pomo", selectedMode, isPro)
        Spacer(modifier = GlanceModifier.width(4.dp))
        ModeChip(context, FocusMode.Flow, "Flow", selectedMode, isPro)
        Spacer(modifier = GlanceModifier.width(4.dp))
        ModeChip(context, FocusMode.Blocks, "Blocks", selectedMode, isPro)
        Spacer(modifier = GlanceModifier.width(4.dp))
        ModeChip(context, FocusMode.Chrono, "Chrono", selectedMode, isPro)
    }
}

@Composable
private fun ModeChip(context: Context, mode: FocusMode, label: String, selectedMode: FocusMode?, isPro: Boolean) {
    val isSelected = mode == selectedMode
    val isLocked = !mode.isFreeTier && !isPro
    val color = modeColor(mode)
    val bgColor = when {
        isSelected -> color
        isLocked -> ColorProvider(R.color.widget_stop_bg).getColor(context).copy(alpha = 0.5f)
        else -> ColorProvider(R.color.widget_stop_bg)
    }
    val textColor = if (isSelected) ColorProvider(R.color.widget_white) else ColorProvider(R.color.widget_stop_text)

    Box(
        modifier = GlanceModifier
            .background(if (isSelected) color else ColorProvider(R.color.widget_stop_bg))
            .cornerRadius(14.dp)
            .clickable(if (isLocked) actionStartActivity<MainActivity>() else actionRunCallback<SelectModeAction>(
                actionParametersOf(modeParam to mode.name),
            ))
            .padding(horizontal = 12.dp, vertical = 6.dp),
        contentAlignment = Alignment.Center,
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            if (isLocked) {
                Text(
                    text = "\uD83D\uDD12 ",
                    style = TextStyle(fontSize = 10.sp),
                )
            }
            Text(
                text = label,
                style = TextStyle(
                    fontSize = 11.sp,
                    fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Medium,
                    color = if (isLocked && !isSelected) textColor.getColor(context).copy(alpha = 0.5f) else textColor,
                ),
            )
        }
    }
}

val modeParam = ActionParameters.Key<String>("mode")

class SelectModeAction : ActionCallback {
    override suspend fun onAction(context: Context, glanceId: GlanceId, parameters: ActionParameters) {
        val modeName = parameters[modeParam] ?: FocusMode.Pomodoro.name
        val mode = FocusMode.entries.find { it.name == modeName } ?: FocusMode.Pomodoro

        updateAppWidgetState(context, PreferencesGlanceStateDefinition, glanceId) { prefs ->
            prefs.toMutablePreferences().apply {
                this[PREF_MODE] = mode.name
                this[PREF_SELECTED_MODE] = mode.name
                this[PREF_DISPLAY] = mode.defaultDisplayTime
                this[PREF_PHASE] = mode.label
                this[PREF_STATUS] = TimerStatus.Idle.name
                this[PREF_PROGRESS] = 1f
                remove(PREF_LINKED_TASK)
            }
        }
        FocusTimerWidget().update(context, glanceId)
    }
}

class StartAction : ActionCallback {
    override suspend fun onAction(context: Context, glanceId: GlanceId, parameters: ActionParameters) {
        val modeName = parameters[modeParam] ?: FocusMode.Pomodoro.name

        context.startForegroundService(
            Intent(context, FocusTimerService::class.java).apply {
                action = FocusTimerService.ACTION_START_MODE
                putExtra("mode", modeName)
            },
        )
    }
}

class PauseAction : ActionCallback {
    override suspend fun onAction(context: Context, glanceId: GlanceId, parameters: ActionParameters) {
        context.startForegroundService(
            Intent(context, FocusTimerService::class.java).apply { action = FocusTimerService.ACTION_PAUSE },
        )
        // Optimistic update: immediately show Resume button
        updateAppWidgetState(context, PreferencesGlanceStateDefinition, glanceId) { prefs ->
            prefs.toMutablePreferences().apply {
                this[PREF_STATUS] = TimerStatus.Paused.name
            }
        }
        FocusTimerWidget().update(context, glanceId)
    }
}

class ResumeAction : ActionCallback {
    override suspend fun onAction(context: Context, glanceId: GlanceId, parameters: ActionParameters) {
        context.startForegroundService(
            Intent(context, FocusTimerService::class.java).apply { action = FocusTimerService.ACTION_RESUME },
        )
        // Optimistic update: immediately show Pause button
        updateAppWidgetState(context, PreferencesGlanceStateDefinition, glanceId) { prefs ->
            prefs.toMutablePreferences().apply {
                this[PREF_STATUS] = TimerStatus.Running.name
            }
        }
        FocusTimerWidget().update(context, glanceId)
    }
}

class StopAction : ActionCallback {
    override suspend fun onAction(context: Context, glanceId: GlanceId, parameters: ActionParameters) {
        context.startService(
            Intent(context, FocusTimerService::class.java).apply { action = FocusTimerService.ACTION_STOP },
        )
        // Reset widget to idle state
        updateAppWidgetState(context, PreferencesGlanceStateDefinition, glanceId) { prefs ->
            prefs.toMutablePreferences().apply {
                this[PREF_MODE] = FocusMode.Pomodoro.name
                remove(PREF_SELECTED_MODE)
                this[PREF_DISPLAY] = FocusMode.Pomodoro.defaultDisplayTime
                this[PREF_PHASE] = FocusMode.Pomodoro.label
                this[PREF_STATUS] = TimerStatus.Idle.name
                this[PREF_PROGRESS] = 1f
                remove(PREF_LINKED_TASK)
            }
        }
        FocusTimerWidget().update(context, glanceId)
    }
}

class FocusTimerWidgetReceiver : GlanceAppWidgetReceiver() {
    override val glanceAppWidget: GlanceAppWidget = FocusTimerWidget()

    override fun onEnabled(context: Context) {
        super.onEnabled(context)
        // Clear any stale state when first added — Glance DataStore will start empty
        // which maps to default TimerWidgetState (Idle), so no explicit write needed.
        // Force a refresh in case there's stale DataStore state from a previous install.
        CoroutineScope(Dispatchers.IO).launch {
            updateWidgetState(
                context,
                TimerWidgetState(
                    mode = FocusMode.Pomodoro,
                    selectedMode = null,
                    displayTime = FocusMode.Pomodoro.defaultDisplayTime,
                    phaseLabel = FocusMode.Pomodoro.label,
                    status = TimerStatus.Idle,
                    progress = 1f,
                ),
            )
            FocusTimerWidget().updateAll(context)
        }
    }
}
