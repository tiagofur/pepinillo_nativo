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
import androidx.glance.appwidget.state.getAppWidgetState
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
            val isPro = entryPoint.subscriptionManager().subscriptionState.value.hasLocalPremium
            updateAppWidgetState(context, PreferencesGlanceStateDefinition, id) { prefs ->
                prefs.toMutablePreferences().apply {
                    this[PREF_FOCUS_IS_PRO] = isPro
                }
            }
        } catch (e: Exception) {
            // Ignore
        }

        provideContent {
            GlanceTheme {
                val prefs = currentState<Preferences>()
                val state = prefsToTimerState(context, prefs)
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

suspend fun updateWidgetState(context: Context, state: TimerWidgetState) {
    val manager = GlanceAppWidgetManager(context)
    val glanceIds = manager.getGlanceIds(FocusTimerWidget::class.java)
    glanceIds.forEach { glanceId ->
        updateAppWidgetState(context, PreferencesGlanceStateDefinition, glanceId) { prefs ->
            prefs.toMutablePreferences().apply {
                this[PREF_MODE] = state.mode.name
                if (state.selectedMode != null) {
                    this[PREF_SELECTED_MODE] = state.selectedMode.name
                }
                this[PREF_DISPLAY] = state.displayTime
                this[PREF_PHASE] = state.phaseLabel
                this[PREF_STATUS] = state.status.name
                this[PREF_PROGRESS] = state.progress
                if (state.finishTimestamp != null) {
                    this[PREF_FINISH_TIMESTAMP] = state.finishTimestamp.toString()
                } else {
                    remove(PREF_FINISH_TIMESTAMP)
                }
                if (state.linkedTaskName != null) {
                    this[PREF_LINKED_TASK] = state.linkedTaskName
                } else {
                    remove(PREF_LINKED_TASK)
                }
            }
        }
    }
}

private val PREF_MODE = stringPreferencesKey("mode")
private val PREF_SELECTED_MODE = stringPreferencesKey("selected_mode")
private val PREF_DISPLAY = stringPreferencesKey("display")
private val PREF_PHASE = stringPreferencesKey("phase")
private val PREF_STATUS = stringPreferencesKey("status")
private val PREF_PROGRESS = floatPreferencesKey("progress")
private val PREF_FINISH_TIMESTAMP = stringPreferencesKey("finish_timestamp")
private val PREF_LINKED_TASK = stringPreferencesKey("linked_task")
private val PREF_FOCUS_IS_PRO = androidx.datastore.preferences.core.booleanPreferencesKey("is_pro")

private fun prefsToTimerState(context: Context, prefs: Preferences): TimerWidgetState {
    val mode = FocusMode.valueOf(prefs[PREF_MODE] ?: FocusMode.Pomodoro.name)
    return TimerWidgetState(
        mode = mode,
        selectedMode = prefs[PREF_SELECTED_MODE]?.let { FocusMode.valueOf(it) },
        displayTime = prefs[PREF_DISPLAY] ?: mode.defaultDisplayTime,
        finishTimestamp = prefs[PREF_FINISH_TIMESTAMP]?.toLongOrNull(),
        phaseLabel = prefs[PREF_PHASE] ?: context.getString(mode.labelRes),
        status = TimerStatus.valueOf(prefs[PREF_STATUS] ?: TimerStatus.Idle.name),
        progress = prefs[PREF_PROGRESS] ?: 1f,
        linkedTaskName = prefs[PREF_LINKED_TASK],
        isPro = prefs[PREF_FOCUS_IS_PRO] ?: false,
    )
}

@Composable
private fun IdleWidget(context: Context, state: TimerWidgetState) {
    Column(
        modifier = GlanceModifier.fillMaxSize()
            .background(GlanceTheme.colors.surface)
            .padding(12.dp)
            .clickable(actionStartActivity<MainActivity>()),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            text = context.getString(R.string.app_name),
            style = TextStyle(
                color = GlanceTheme.colors.onSurface,
                fontSize = 12.sp,
                fontWeight = FontWeight.Medium,
            ),
        )
        Spacer(GlanceModifier.height(8.dp))
        Row(
            modifier = GlanceModifier.fillMaxWidth(),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            FocusMode.values().forEach { mode ->
                ModeChip(
                    mode = mode,
                    label = context.getString(mode.labelRes),
                    selectedMode = state.selectedMode,
                    isPro = state.isPro,
                )
            }
        }
        Spacer(GlanceModifier.height(8.dp))
        Text(
            text = context.getString(R.string.btn_get_started),
            style = TextStyle(
                color = GlanceTheme.colors.onSurfaceVariant,
                fontSize = 11.sp,
                textAlign = TextAlign.Center,
            ),
        )
    }
}

@Composable
private fun ReadyWidget(context: Context, state: TimerWidgetState) {
    val mode = state.selectedMode ?: state.mode
    Column(
        modifier = GlanceModifier.fillMaxSize()
            .background(GlanceTheme.colors.surface)
            .padding(12.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Row(
            modifier = GlanceModifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                text = context.getString(mode.labelRes),
                style = TextStyle(
                    color = GlanceTheme.colors.onSurface,
                    fontSize = 14.sp,
                    fontWeight = FontWeight.Bold,
                ),
                modifier = GlanceModifier.defaultWeight(),
            )
            Text(
                text = state.displayTime,
                style = TextStyle(
                    color = GlanceTheme.colors.primary,
                    fontSize = 18.sp,
                    fontWeight = FontWeight.Medium,
                ),
            )
        }
        Spacer(GlanceModifier.height(12.dp))
        Row(
            modifier = GlanceModifier.fillMaxWidth(),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Box(
                modifier = GlanceModifier
                    .background(GlanceTheme.colors.primaryContainer)
                    .cornerRadius(16.dp)
                    .padding(horizontal = 24.dp, vertical = 8.dp)
                    .clickable(actionRunCallback<StartAction>()),
                contentAlignment = Alignment.Center,
            ) {
                Text(
                    text = context.getString(R.string.btn_start_focus),
                    style = TextStyle(
                        color = GlanceTheme.colors.onPrimaryContainer,
                        fontSize = 13.sp,
                        fontWeight = FontWeight.Bold,
                    ),
                )
            }
        }
    }
}

@Composable
private fun RunningWidget(context: Context, state: TimerWidgetState) {
    val mode = state.mode
    Column(
        modifier = GlanceModifier.fillMaxSize()
            .background(GlanceTheme.colors.surface)
            .padding(12.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            text = "${context.getString(mode.labelRes)} \u2022 ${state.phaseLabel}",
            style = TextStyle(
                color = GlanceTheme.colors.onSurfaceVariant,
                fontSize = 11.sp,
            ),
        )
        Text(
            text = state.displayTime,
            style = TextStyle(
                color = GlanceTheme.colors.onSurface,
                fontSize = 32.sp,
                fontWeight = FontWeight.Bold,
            ),
        )
        Spacer(GlanceModifier.height(8.dp))
        Row(
            modifier = GlanceModifier.fillMaxWidth(),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            val isRunning = state.status == TimerStatus.Running
            val action = if (isRunning) FocusTimerService.ACTION_PAUSE else FocusTimerService.ACTION_RESUME
            val label = if (isRunning) R.string.btn_pause else R.string.btn_resume
            
            Box(
                modifier = GlanceModifier
                    .background(GlanceTheme.colors.secondaryContainer)
                    .cornerRadius(12.dp)
                    .padding(horizontal = 16.dp, vertical = 6.dp)
                    .clickable(actionRunCallback<PauseResumeAction>()),
                contentAlignment = Alignment.Center,
            ) {
                Text(
                    text = context.getString(label),
                    style = TextStyle(color = GlanceTheme.colors.onSecondaryContainer, fontSize = 12.sp),
                )
            }
            Spacer(GlanceModifier.width(8.dp))
            Box(
                modifier = GlanceModifier
                    .background(GlanceTheme.colors.errorContainer)
                    .cornerRadius(12.dp)
                    .padding(horizontal = 16.dp, vertical = 6.dp)
                    .clickable(actionRunCallback<StopAction>()),
                contentAlignment = Alignment.Center,
            ) {
                Text(
                    text = context.getString(R.string.btn_stop),
                    style = TextStyle(color = GlanceTheme.colors.onErrorContainer, fontSize = 12.sp),
                )
            }
        }
    }
}

@Composable
private fun ModeChip(mode: FocusMode, label: String, selectedMode: FocusMode?, isPro: Boolean) {
    val isSelected = selectedMode == mode
    val isLocked = !mode.isFreeTier && !isPro
    
    Box(
        modifier = GlanceModifier
            .padding(horizontal = 4.dp)
            .background(if (isSelected) GlanceTheme.colors.primary else GlanceTheme.colors.surfaceVariant)
            .cornerRadius(8.dp)
            .padding(horizontal = 8.dp, vertical = 4.dp)
            .clickable(actionRunCallback<SelectModeAction>(actionParametersOf(PARAM_MODE to mode.name))),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text = if (isLocked) "\uD83D\uDD12 $label" else label,
            style = TextStyle(
                color = if (isSelected) GlanceTheme.colors.onPrimary else GlanceTheme.colors.onSurfaceVariant,
                fontSize = 10.sp,
            ),
        )
    }
}

private val PARAM_MODE = ActionParameters.Key<String>("mode")

class SelectModeAction : ActionCallback {
    override suspend fun onAction(context: Context, glanceId: GlanceId, parameters: ActionParameters) {
        val modeName = parameters[PARAM_MODE] ?: return
        val mode = FocusMode.valueOf(modeName)
        
        updateAppWidgetState(context, PreferencesGlanceStateDefinition, glanceId) { prefs ->
            prefs.toMutablePreferences().apply {
                this[PREF_SELECTED_MODE] = mode.name
                this[PREF_DISPLAY] = mode.defaultDisplayTime
                this[PREF_PHASE] = context.getString(mode.labelRes)
            }
        }
        FocusTimerWidget().update(context, glanceId)
    }
}

class StartAction : ActionCallback {
    override suspend fun onAction(context: Context, glanceId: GlanceId, parameters: ActionParameters) {
        // Find selected mode from prefs
        val state = getAppWidgetState<Preferences>(context, PreferencesGlanceStateDefinition, glanceId)
        val modeName = state[PREF_SELECTED_MODE] ?: FocusMode.Pomodoro.name
        
        context.startService(
            Intent(context, FocusTimerService::class.java).apply {
                action = FocusTimerService.ACTION_START_MODE
                putExtra(FocusTimerService.EXTRA_MODE, modeName)
            },
        )
    }
}

class PauseResumeAction : ActionCallback {
    override suspend fun onAction(context: Context, glanceId: GlanceId, parameters: ActionParameters) {
        val state = getAppWidgetState<Preferences>(context, PreferencesGlanceStateDefinition, glanceId)
        val isRunning = state[PREF_STATUS] == TimerStatus.Running.name
        val action = if (isRunning) FocusTimerService.ACTION_PAUSE else FocusTimerService.ACTION_RESUME
        
        context.startService(
            Intent(context, FocusTimerService::class.java).apply { this.action = action },
        )
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
                this[PREF_PHASE] = context.getString(FocusMode.Pomodoro.labelRes)
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
        CoroutineScope(Dispatchers.IO).launch {
            updateAppWidgetState(context, PreferencesGlanceStateDefinition, GlanceAppWidgetManager(context).getGlanceIds(FocusTimerWidget::class.java).firstOrNull() ?: return@launch) { prefs ->
                prefs.toMutablePreferences().apply {
                    this[PREF_MODE] = FocusMode.Pomodoro.name
                    this[PREF_DISPLAY] = FocusMode.Pomodoro.defaultDisplayTime
                    this[PREF_PHASE] = context.getString(FocusMode.Pomodoro.labelRes)
                    this[PREF_STATUS] = TimerStatus.Idle.name
                    this[PREF_PROGRESS] = 1f
                }
            }
            FocusTimerWidget().updateAll(context)
        }
    }
}


