package dev.creapolis.pepinillo.widget

import android.content.Context
import android.content.Intent
import android.content.res.Configuration
import android.view.View
import androidx.compose.runtime.Composable
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.floatPreferencesKey
import androidx.datastore.preferences.core.intPreferencesKey
import androidx.datastore.preferences.core.stringPreferencesKey
import android.os.SystemClock
import android.os.Build
import android.widget.RemoteViews
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.GlanceTheme
import androidx.glance.appwidget.AndroidRemoteViews
import androidx.glance.action.ActionParameters
import androidx.glance.action.actionParametersOf
import androidx.glance.action.actionStartActivity
import androidx.glance.action.clickable
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.GlanceAppWidgetManager
import androidx.glance.appwidget.GlanceAppWidgetReceiver
import androidx.glance.appwidget.action.ActionCallback
import androidx.glance.appwidget.action.actionRunCallback
import androidx.glance.appwidget.appWidgetBackground
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
import androidx.glance.layout.fillMaxHeight
import androidx.glance.layout.height
import androidx.glance.layout.padding
import androidx.glance.layout.size
import androidx.glance.layout.width
import androidx.glance.LocalSize
import androidx.compose.ui.unit.DpSize
import androidx.glance.state.PreferencesGlanceStateDefinition
import androidx.glance.text.FontWeight
import androidx.glance.text.Text
import androidx.glance.text.TextAlign
import androidx.glance.text.TextStyle
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.toArgb
import dev.creapolis.pepinillo.ui.theme.AppTheme
import dev.creapolis.pepinillo.ui.theme.breakVariant
import dev.creapolis.pepinillo.domain.timer.FocusPhase
import dev.creapolis.pepinillo.MainActivity
import dev.creapolis.pepinillo.R
import dev.creapolis.pepinillo.domain.timer.TimerStatus
import dev.creapolis.pepinillo.feature.focus.FocusMode
import dev.creapolis.pepinillo.service.FocusTimerService
import androidx.glance.LocalContext
import androidx.glance.unit.ColorProvider
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

import dagger.hilt.android.EntryPointAccessors
import dev.creapolis.pepinillo.core.billing.SubscriptionManager

import androidx.glance.appwidget.SizeMode

class FocusTimerWidget : GlanceAppWidget() {
    override val stateDefinition = PreferencesGlanceStateDefinition
    override val sizeMode = SizeMode.Exact

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
            val size = LocalSize.current
            val prefs = currentState<Preferences>()
            val state = prefsToTimerState(context, prefs)
            
            // Wrap in GlanceTheme to support dynamic colors
            GlanceTheme {
                DashboardWidget(context, state, size)
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
    val linkedSessions: Int = 0,
    val streak: Int = 0,
    val sessionsToday: Int = 0,
    val linkedTaskTitle: String? = null,
    val themeId: String = "materialYou",
    val phase: FocusPhase = FocusPhase.Work,
    val elapsedMillis: Long = 0L,
    val themeMode: String = "System",
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
                this[PREF_ELAPSED] = state.elapsedMillis.toString()
                this[PREF_STREAK] = state.streak
                this[PREF_SESSIONS] = state.sessionsToday
                if (state.linkedTaskTitle != null) {
                    this[PREF_LINKED_TASK_TITLE] = state.linkedTaskTitle
                } else {
                    remove(PREF_LINKED_TASK_TITLE)
                }
                this[PREF_THEME_ID] = state.themeId
                this[PREF_PHASE_ENUM] = state.phase.name
                this[PREF_THEME_MODE] = state.themeMode
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
private val PREF_FOCUS_IS_PRO = booleanPreferencesKey("is_pro")
private val PREF_ELAPSED = stringPreferencesKey("elapsed_millis")
private val PREF_STREAK = intPreferencesKey("streak")
private val PREF_SESSIONS = intPreferencesKey("sessions")
private val PREF_LINKED_TASK_TITLE = stringPreferencesKey("linked_task_title")
private val PREF_THEME_ID = stringPreferencesKey("selected_theme")
private val PREF_PHASE_ENUM = stringPreferencesKey("phase_enum")
private val PREF_THEME_MODE = stringPreferencesKey("theme_mode")

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
        isPro = prefs[PREF_FOCUS_IS_PRO] ?: false,
        elapsedMillis = prefs[PREF_ELAPSED]?.toLongOrNull() ?: 0L,
        streak = prefs[PREF_STREAK] ?: 0,
        sessionsToday = prefs[PREF_SESSIONS] ?: 0,
        linkedTaskTitle = prefs[PREF_LINKED_TASK_TITLE],
        themeId = prefs[PREF_THEME_ID] ?: "materialYou",
        phase = prefs[PREF_PHASE_ENUM]?.let { FocusPhase.valueOf(it) } ?: FocusPhase.Work,
        themeMode = prefs[PREF_THEME_MODE] ?: "System"
    )
}

// ─────────────────────────────────────────────────────────────
// Dashboard Widget — unified for Ready / Running / Paused
// Two-column layout matching the premium reference design
// ─────────────────────────────────────────────────────────────
@Composable
private fun DashboardWidget(context: Context, state: TimerWidgetState, size: DpSize) {
    val mode = state.mode
    val isRunning = state.status == TimerStatus.Running
    val isPaused = state.status == TimerStatus.Paused
    val isActive = isRunning || isPaused
    
    val isDark = when (state.themeMode) {
        "Dark" -> true
        "Light" -> false
        else -> (context.resources.configuration.uiMode and android.content.res.Configuration.UI_MODE_NIGHT_MASK) == android.content.res.Configuration.UI_MODE_NIGHT_YES
    }

    // Enforce MaterialYou if not PRO
    val themeId = (if (state.isPro) state.themeId else "materialYou").lowercase()
    val isMaterialYou = themeId == "materialYou"
    
    val theme = AppTheme.named(themeId)
    val baseAccent = when (mode) {
        FocusMode.Pomodoro -> theme.pomodoroColor
        FocusMode.Flow -> theme.flowtimeColor
        FocusMode.Blocks -> theme.timeBlockColor
        FocusMode.Chrono -> theme.stopwatchColor
    }
    val accentColor = baseAccent.breakVariant(state.phase)
    val accentColorProvider = ColorProvider(accentColor)
    val onAccentColor = if (isDark) Color.Black else Color.White
    val onAccentColorProvider = ColorProvider(onAccentColor)

    // Match Focus Screen background logic: blend base surface with mode accent color when active
    val isIdle = state.status == TimerStatus.Idle
    // Use a slightly more neutral base for blending to avoid "yellowish" look
    val baseSurfaceColor = if (isDark) Color(0xFF12140E) else Color(0xFFFBFDF9)
    val finalSurfaceColor = if (!isIdle) {
        val alpha = if (isDark) 0.15f else 0.10f
        Color(
            red = accentColor.red * alpha + baseSurfaceColor.red * (1f - alpha),
            green = accentColor.green * alpha + baseSurfaceColor.green * (1f - alpha),
            blue = accentColor.blue * alpha + baseSurfaceColor.blue * (1f - alpha),
            alpha = 1f
        )
    } else {
        baseSurfaceColor
    }

    // Always use GlanceTheme colors when Idle for perfect system integration,
    // only use custom providers when we need the specific focus mode tint.
    val surfaceProvider = if (isIdle) GlanceTheme.colors.widgetBackground else ColorProvider(finalSurfaceColor)
    val onSurfaceProvider = if (isIdle) GlanceTheme.colors.onSurface else ColorProvider(if (isDark) Color(0xFFE2E3D8) else Color(0xFF1A1C18))
    val onSurfaceVariantProvider = if (isIdle) GlanceTheme.colors.onSurfaceVariant else ColorProvider(if (isDark) Color(0xFFC3C8BB) else Color(0xFF43483E))
    val surfaceVariantProvider = if (isIdle) GlanceTheme.colors.surfaceVariant else ColorProvider(if (isDark) Color(0xFF43483E) else Color(0xFFDFE4D7))

    Row(
        modifier = GlanceModifier.fillMaxSize()
            .appWidgetBackground()
            .background(surfaceProvider)
            .cornerRadius(24.dp)
            .clickable(actionStartActivity<MainActivity>()),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        // ── Left Side: Timer (Balanced 50% weight) ──
        Box(
            modifier = GlanceModifier.defaultWeight().fillMaxHeight(),
            contentAlignment = Alignment.Center
        ) {
            val availableWidth = size.width / 2
            val availableHeight = size.height
            val maxRingSize = minOf(availableWidth, availableHeight) - 24.dp
            val ringSize = maxRingSize.coerceAtLeast(80.dp)
            TimerRing(context, state, mode, isRunning, isDark, ringSize, accentColor)
        }

        // ── Right Side: Controls (Balanced 50% weight) ──
        Column(
            modifier = GlanceModifier.defaultWeight().fillMaxHeight().padding(horizontal = 8.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            // Task info
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                Text(
                    text = state.linkedTaskTitle ?: "No Task",
                    style = TextStyle(
                        color = onSurfaceProvider,
                        fontSize = 20.sp,
                        fontWeight = FontWeight.Bold,
                        textAlign = TextAlign.Center,
                    ),
                    maxLines = 1,
                )
            }

            Spacer(GlanceModifier.height(16.dp))

            // Controls row
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalAlignment = Alignment.CenterHorizontally
            ) {
                val primaryIcon = if (isRunning) R.drawable.ic_pause else R.drawable.ic_play
                
                Box(
                    modifier = GlanceModifier
                        .background(accentColorProvider)
                        .cornerRadius(36.dp)
                        .size(72.dp)
                        .clickable(
                            if (isActive) actionRunCallback<PauseResumeAction>()
                            else actionRunCallback<StartAction>()
                        ),
                    contentAlignment = Alignment.Center,
                ) {
                    androidx.glance.Image(
                        provider = androidx.glance.ImageProvider(primaryIcon),
                        contentDescription = "Play/Pause",
                        colorFilter = androidx.glance.ColorFilter.tint(onAccentColorProvider),
                        modifier = GlanceModifier.size(36.dp)
                    )
                }

                Spacer(GlanceModifier.width(16.dp))

                Box(
                    modifier = GlanceModifier
                        .background(surfaceVariantProvider)
                        .cornerRadius(20.dp)
                        .size(40.dp)
                        .clickable(actionRunCallback<StopAction>()),
                    contentAlignment = Alignment.Center,
                ) {
                    androidx.glance.Image(
                        provider = androidx.glance.ImageProvider(R.drawable.ic_stop),
                        contentDescription = "Stop",
                        colorFilter = androidx.glance.ColorFilter.tint(onSurfaceVariantProvider),
                        modifier = GlanceModifier.size(20.dp)
                    )
                }
            }

            Spacer(GlanceModifier.height(8.dp))
            
            if (isActive) {
                // Stats row (only when running)
                Row(
                    modifier = GlanceModifier.fillMaxWidth(),
                    horizontalAlignment = Alignment.CenterHorizontally
                ) {
                    // Streak
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Text(text = "\uD83D\uDD25", style = TextStyle(fontSize = 16.sp))
                        Spacer(GlanceModifier.width(4.dp))
                        Column(horizontalAlignment = Alignment.CenterHorizontally) {
                            Text(
                                text = "${state.streak}",
                                style = TextStyle(
                                    color = onSurfaceProvider,
                                    fontSize = 18.sp,
                                    fontWeight = FontWeight.Bold,
                                ),
                            )
                            Text(
                                text = "racha",
                                style = TextStyle(
                                    color = onSurfaceVariantProvider,
                                    fontSize = 12.sp,
                                ),
                            )
                        }
                    }

                    Spacer(GlanceModifier.width(12.dp))

                    // Sessions
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Text(text = "\u2705", style = TextStyle(fontSize = 16.sp))
                        Spacer(GlanceModifier.width(4.dp))
                        Column(horizontalAlignment = Alignment.CenterHorizontally) {
                            Text(
                                text = "${state.sessionsToday}",
                                style = TextStyle(
                                    color = onSurfaceProvider,
                                    fontSize = 18.sp,
                                    fontWeight = FontWeight.Bold,
                                ),
                            )
                            Text(
                                text = "sesiones",
                                style = TextStyle(
                                    color = onSurfaceVariantProvider,
                                    fontSize = 12.sp,
                                ),
                            )
                        }
                    }
                }
            } else {
                // Mode selector (only when idle)
                Row(
                    modifier = GlanceModifier.fillMaxWidth(),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    FocusMode.entries
                        .filter { state.isPro || it.isFreeTier }
                        .forEach { m ->
                            val isSelected = m == mode
                            val emoji = when (m) {
                                FocusMode.Pomodoro -> "\u23F1\uFE0F" // ⏱️
                                FocusMode.Flow -> "\u267E\uFE0F"     // ♾️
                                FocusMode.Blocks -> "\uD83E\uDDF1"  // 🧱
                                FocusMode.Chrono -> "\u26A1"      // ⚡
                            }
                        
                        Box(
                            modifier = GlanceModifier
                                .padding(horizontal = 4.dp)
                                .size(40.dp)
                                .cornerRadius(20.dp)
                                .background(if (isSelected) onSurfaceProvider else surfaceVariantProvider)
                                .clickable(actionRunCallback<SelectModeAction>(actionParametersOf(ActionParameters.Key<String>("mode") to m.name))),
                            contentAlignment = Alignment.Center
                        ) {
                            Text(
                                text = emoji,
                                style = TextStyle(
                                    fontSize = 18.sp,
                                    color = if (isSelected) surfaceProvider else onSurfaceProvider
                                )
                            )
                        }
                    }
                }
            }
        }
    }
}

// ─────────────────────────────────────────────────────────────
// Timer Ring — RemoteViews-based determinate circular progress
// ─────────────────────────────────────────────────────────────
@Composable
private fun TimerRing(
    context: Context,
    state: TimerWidgetState,
    mode: FocusMode,
    isRunning: Boolean,
    isDark: Boolean,
    size: androidx.compose.ui.unit.Dp,
    accentColor: Color,
) {
    val rv = RemoteViews(context.packageName, R.layout.widget_timer_ring)

    // Set determinate progress (1.0 = full ring, 0.0 = empty ring)
    val progressValue = (state.progress * 10000).toInt().coerceIn(0, 10000)
    rv.setProgressBar(R.id.progress_ring, 10000, progressValue, false)
    
    // Tint the progress ring using setColorStateList (API 31+) or setColorFilter (older)
    try {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            rv.setColorStateList(
                R.id.progress_ring,
                "setProgressTintList",
                android.content.res.ColorStateList.valueOf(accentColor.toArgb())
            )
        } else {
            // Best effort for older versions: use setInt with "setColorFilter"
            // Note: Some ProgressBar implementations might not support this via RemoteViews
            rv.setInt(R.id.progress_ring, "setColorFilter", accentColor.toArgb())
        }
    } catch (e: Exception) {
        // Fallback or ignore if not supported
    }

    // Adapt text colors for dark/light mode
    val textColor = if (isDark) 0xFFE6E1E5.toInt() else 0xFF1C1B1F.toInt()
    val subtextColor = if (isDark) 0xFFCAC4D0.toInt() else 0xFF49454F.toInt()

    if (isRunning) {
        // Show native Chronometer for real-time ticking
        rv.setViewVisibility(R.id.timer_chronometer, View.VISIBLE)
        rv.setViewVisibility(R.id.timer_static_text, View.GONE)
        rv.setTextColor(R.id.timer_chronometer, textColor)

        val isCountDown = mode.defaultTotalSeconds != null
        if (isCountDown && state.finishTimestamp != null) {
            val remaining = (state.finishTimestamp - System.currentTimeMillis()).coerceAtLeast(0L)
            rv.setChronometer(
                R.id.timer_chronometer,
                SystemClock.elapsedRealtime() + remaining,
                null,
                true,
            )
            rv.setChronometerCountDown(R.id.timer_chronometer, true)
        } else {
            rv.setChronometer(
                R.id.timer_chronometer,
                SystemClock.elapsedRealtime() - state.elapsedMillis,
                null,
                true,
            )
            rv.setChronometerCountDown(R.id.timer_chronometer, false)
        }
    } else {
        // Show static time text (ready or paused)
        rv.setViewVisibility(R.id.timer_chronometer, View.GONE)
        rv.setViewVisibility(R.id.timer_static_text, View.VISIBLE)
        rv.setTextViewText(R.id.timer_static_text, state.displayTime)
        rv.setTextColor(R.id.timer_static_text, textColor)
    }

    // Phase label
    rv.setTextViewText(R.id.phase_label, context.getString(mode.labelRes))
    rv.setTextColor(R.id.phase_label, subtextColor)

    // Dynamic text sizing based on the ring size
    val timerTextSizeSp = size.value * 0.32f
    val labelTextSizeSp = size.value * 0.14f
    
    rv.setTextViewTextSize(R.id.timer_chronometer, android.util.TypedValue.COMPLEX_UNIT_SP, timerTextSizeSp)
    rv.setTextViewTextSize(R.id.timer_static_text, android.util.TypedValue.COMPLEX_UNIT_SP, timerTextSizeSp)
    rv.setTextViewTextSize(R.id.phase_label, android.util.TypedValue.COMPLEX_UNIT_SP, labelTextSizeSp)

    AndroidRemoteViews(rv, modifier = GlanceModifier.size(size))
}

// ─────────────────────────────────────────────────────────────
// Actions
// ─────────────────────────────────────────────────────────────

class SelectModeAction : ActionCallback {
    override suspend fun onAction(context: Context, glanceId: GlanceId, parameters: ActionParameters) {
        val modeName = parameters[ActionParameters.Key<String>("mode")] ?: return
        val mode = FocusMode.valueOf(modeName)
        
        val currentPrefs = getAppWidgetState<Preferences>(context, PreferencesGlanceStateDefinition, glanceId)
        val isPro = currentPrefs[PREF_FOCUS_IS_PRO] ?: false
        
        if (!isPro && !mode.isFreeTier) {
            // Not a pro user, can't select this mode. Redirect to app.
            context.startActivity(Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
            })
            return
        }
        
        updateAppWidgetState(context, PreferencesGlanceStateDefinition, glanceId) { prefs ->
            prefs.toMutablePreferences().apply {
                this[PREF_MODE] = mode.name
                this[PREF_SELECTED_MODE] = mode.name
                this[PREF_DISPLAY] = mode.defaultDisplayTime
                this[PREF_PHASE] = context.getString(mode.labelRes)
                this[PREF_PROGRESS] = 1f
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
