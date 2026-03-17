package dev.creapolis.pepinillo.widget

import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import androidx.compose.runtime.Composable
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.GlanceTheme
import androidx.glance.action.ActionParameters
import androidx.glance.action.actionParametersOf
import androidx.glance.action.actionStartActivity
import androidx.glance.action.clickable
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.GlanceAppWidgetReceiver
import androidx.glance.appwidget.action.ActionCallback
import androidx.glance.appwidget.action.actionRunCallback
import androidx.glance.appwidget.cornerRadius
import androidx.glance.appwidget.provideContent
import androidx.glance.appwidget.updateAll
import androidx.glance.background
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

class FocusTimerWidget : GlanceAppWidget() {
    override suspend fun provideGlance(context: Context, id: GlanceId) {
        provideContent {
            GlanceTheme {
                val state = readTimerState(context)
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
    val phaseLabel: String = "Focus",
    val status: TimerStatus = TimerStatus.Idle,
    val progress: Float = 1f,
)

private const val WIDGET_PREFS = "focus_timer_widget"
private const val KEY_MODE = "widget_mode"
private const val KEY_SELECTED_MODE = "widget_selected_mode"
private const val KEY_DISPLAY = "widget_display"
private const val KEY_PHASE = "widget_phase"
private const val KEY_STATUS = "widget_status"
private const val KEY_PROGRESS = "widget_progress"

private fun prefs(context: Context): SharedPreferences =
    context.getSharedPreferences(WIDGET_PREFS, Context.MODE_PRIVATE)

private fun readTimerState(context: Context): TimerWidgetState {
    val prefs = prefs(context)
    val modeName = prefs.getString(KEY_MODE, FocusMode.Pomodoro.name) ?: FocusMode.Pomodoro.name
    val selectedModeName = prefs.getString(KEY_SELECTED_MODE, null)
    val mode = FocusMode.entries.find { it.name == modeName } ?: FocusMode.Pomodoro
    val selectedMode = selectedModeName?.let { name -> FocusMode.entries.find { it.name == name } }
    val statusName = prefs.getString(KEY_STATUS, TimerStatus.Idle.name) ?: TimerStatus.Idle.name
    val status = TimerStatus.entries.find { it.name == statusName } ?: TimerStatus.Idle
    
    return TimerWidgetState(
        mode = mode,
        selectedMode = selectedMode,
        displayTime = prefs.getString(KEY_DISPLAY, mode.defaultDisplayTime) ?: mode.defaultDisplayTime,
        phaseLabel = prefs.getString(KEY_PHASE, mode.label) ?: mode.label,
        status = status,
        progress = prefs.getFloat(KEY_PROGRESS, 1f),
    )
}

fun updateWidgetState(context: Context, state: TimerWidgetState) {
    prefs(context).edit()
        .putString(KEY_MODE, state.mode.name)
        .putString(KEY_SELECTED_MODE, state.selectedMode?.name)
        .putString(KEY_DISPLAY, state.displayTime)
        .putString(KEY_PHASE, state.phaseLabel)
        .putString(KEY_STATUS, state.status.name)
        .putFloat(KEY_PROGRESS, state.progress)
        .apply()
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
        ModeSelectorRow(context, selectedMode = null)
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
        ModeSelectorRow(context, selectedMode = state.selectedMode)
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
        Text(
            text = state.displayTime,
            style = TextStyle(
                fontWeight = FontWeight.Bold,
                fontSize = 36.sp,
                color = color,
                textAlign = TextAlign.Center,
            ),
        )
        Spacer(modifier = GlanceModifier.height(10.dp))
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
private fun ModeSelectorRow(context: Context, selectedMode: FocusMode?) {
    Row(
        modifier = GlanceModifier.fillMaxWidth(),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        ModeChip(context, FocusMode.Pomodoro, "Pomo", selectedMode)
        Spacer(modifier = GlanceModifier.width(4.dp))
        ModeChip(context, FocusMode.Flow, "Flow", selectedMode)
        Spacer(modifier = GlanceModifier.width(4.dp))
        ModeChip(context, FocusMode.Blocks, "Blocks", selectedMode)
        Spacer(modifier = GlanceModifier.width(4.dp))
        ModeChip(context, FocusMode.Chrono, "Chrono", selectedMode)
    }
}

@Composable
private fun ModeChip(context: Context, mode: FocusMode, label: String, selectedMode: FocusMode?) {
    val isSelected = mode == selectedMode
    val color = modeColor(mode)
    val bgColor = if (isSelected) color else ColorProvider(R.color.widget_stop_bg)
    val textColor = if (isSelected) ColorProvider(R.color.widget_white) else ColorProvider(R.color.widget_stop_text)

    Box(
        modifier = GlanceModifier
            .background(bgColor)
            .cornerRadius(14.dp)
            .clickable(actionRunCallback<SelectModeAction>(
                actionParametersOf(modeParam to mode.name),
            ))
            .padding(horizontal = 12.dp, vertical = 6.dp),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text = label,
            style = TextStyle(
                fontSize = 11.sp,
                fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Medium,
                color = textColor,
            ),
        )
    }
}

val modeParam = ActionParameters.Key<String>("mode")

class SelectModeAction : ActionCallback {
    override suspend fun onAction(context: Context, glanceId: GlanceId, parameters: ActionParameters) {
        val modeName = parameters[modeParam] ?: FocusMode.Pomodoro.name
        val mode = FocusMode.entries.find { it.name == modeName } ?: FocusMode.Pomodoro

        // Update SharedPrefs immediately so widget re-renders without waiting for the service
        updateWidgetState(context, TimerWidgetState(
            mode = mode,
            selectedMode = mode,
            displayTime = mode.defaultDisplayTime,
            phaseLabel = mode.label,
            status = TimerStatus.Idle,
            progress = 1f,
        ))

        FocusTimerWidget().updateAll(context = context)
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
    }
}

class ResumeAction : ActionCallback {
    override suspend fun onAction(context: Context, glanceId: GlanceId, parameters: ActionParameters) {
        context.startForegroundService(
            Intent(context, FocusTimerService::class.java).apply { action = FocusTimerService.ACTION_RESUME },
        )
    }
}

class StopAction : ActionCallback {
    override suspend fun onAction(context: Context, glanceId: GlanceId, parameters: ActionParameters) {
        context.startService(
            Intent(context, FocusTimerService::class.java).apply { action = FocusTimerService.ACTION_STOP },
        )
        
        updateWidgetState(context, TimerWidgetState(
            mode = FocusMode.Pomodoro,
            selectedMode = null,
            displayTime = FocusMode.Pomodoro.defaultDisplayTime,
            phaseLabel = FocusMode.Pomodoro.label,
            status = TimerStatus.Idle,
            progress = 1f,
        ))
        
        FocusTimerWidget().updateAll(context = context)
    }
}

class FocusTimerWidgetReceiver : GlanceAppWidgetReceiver() {
    override val glanceAppWidget: GlanceAppWidget = FocusTimerWidget()

    override fun onEnabled(context: Context) {
        super.onEnabled(context)
        // Clear any stale state from a previous widget instance so the widget
        // always starts in the Idle state when first added to the home screen.
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
    }
}
