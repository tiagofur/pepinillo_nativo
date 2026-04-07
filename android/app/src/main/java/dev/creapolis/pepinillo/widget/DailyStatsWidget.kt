package dev.creapolis.pepinillo.widget

import android.content.Context
import androidx.compose.runtime.Composable
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.intPreferencesKey
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.GlanceTheme
import androidx.glance.action.actionStartActivity
import androidx.glance.action.clickable
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.GlanceAppWidgetManager
import androidx.glance.appwidget.GlanceAppWidgetReceiver
import androidx.glance.appwidget.cornerRadius
import androidx.glance.appwidget.provideContent
import androidx.glance.appwidget.state.updateAppWidgetState
import androidx.glance.background
import androidx.glance.currentState
import androidx.glance.layout.Alignment
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
import androidx.glance.layout.Box
import androidx.glance.Image
import androidx.glance.ImageProvider
import androidx.glance.LocalContext
import androidx.glance.unit.ColorProvider
import androidx.glance.color.ColorProvider
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager
import dagger.hilt.android.EntryPointAccessors
import dev.creapolis.pepinillo.MainActivity
import dev.creapolis.pepinillo.R
import dev.creapolis.pepinillo.data.sync.WidgetRefreshWorker
import kotlinx.coroutines.flow.first
import java.util.Calendar

// Glance DataStore preference keys
val PREF_STATS_MINUTES = intPreferencesKey("stats_minutes")
val PREF_STATS_SESSIONS = intPreferencesKey("stats_sessions")
val PREF_STATS_STREAK = intPreferencesKey("stats_streak")
val PREF_STATS_COMPLETED = intPreferencesKey("stats_completed_tasks")
val PREF_IS_PRO = androidx.datastore.preferences.core.booleanPreferencesKey("is_pro")

class DailyStatsWidget : GlanceAppWidget() {
    override val stateDefinition = PreferencesGlanceStateDefinition

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        // Fetch fresh data directly from DB so widget never shows stale/empty state
        try {
            val entryPoint = EntryPointAccessors.fromApplication(
                context.applicationContext, WidgetEntryPoint::class.java,
            )
            val sessionRepo = entryPoint.sessionRepository()
            val taskRepo = entryPoint.taskRepository()
            val subscriptionManager = entryPoint.subscriptionManager()

            val stats = runCatching { sessionRepo.getTodayStats().first() }.getOrNull()
            val allDays = runCatching { sessionRepo.getAllDaysWithSessions().first() }.getOrDefault(emptyList())
            val streak = runCatching { sessionRepo.calculateCurrentStreak(allDays) }.getOrDefault(0)
            val isPro = subscriptionManager.subscriptionState.value.isPro
            
            val startOfDay = Calendar.getInstance().apply {
                set(Calendar.HOUR_OF_DAY, 0)
                set(Calendar.MINUTE, 0)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
            }.timeInMillis
            val completedToday = runCatching { taskRepo.getCompletedTodayCount(startOfDay) }.getOrDefault(0)

            updateAppWidgetState(context, PreferencesGlanceStateDefinition, id) { prefs ->
                prefs.toMutablePreferences().apply {
                    this[PREF_STATS_MINUTES] = stats?.totalMinutes ?: 0
                    this[PREF_STATS_SESSIONS] = stats?.sessionsCompleted ?: 0
                    this[PREF_STATS_STREAK] = streak
                    this[PREF_STATS_COMPLETED] = completedToday
                    this[PREF_IS_PRO] = isPro
                }
            }
        } catch (e: Exception) {
            android.util.Log.e("DailyStatsWidget", "Failed to fetch stats for widget", e)
        }

        provideContent {
            GlanceTheme {
                StatsContent()
            }
        }
    }
}

@Composable
private fun StatsContent() {
    val prefs = currentState<Preferences>()
    val isPro = prefs[PREF_IS_PRO] ?: false
    val minutes = prefs[PREF_STATS_MINUTES] ?: 0
    val sessions = prefs[PREF_STATS_SESSIONS] ?: 0
    val streak = prefs[PREF_STATS_STREAK] ?: 0
    val completedTasks = prefs[PREF_STATS_COMPLETED] ?: 0

    val hours = minutes / 60
    val mins = minutes % 60
    val timeText = if (hours > 0) "${hours}h ${mins}m" else "${mins}m"

    Box(
        modifier = GlanceModifier
            .fillMaxSize()
            .background(GlanceTheme.colors.widgetBackground)
            .cornerRadius(24.dp)
            .clickable(actionStartActivity<MainActivity>()),
        contentAlignment = Alignment.Center,
    ) {
        Column(
            modifier = GlanceModifier.fillMaxSize().padding(16.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                text = "Hoy",
                style = TextStyle(
                    fontSize = 13.sp,
                    fontWeight = FontWeight.Medium,
                    color = GlanceTheme.colors.primary,
                ),
            )

            Spacer(modifier = GlanceModifier.height(12.dp))

            Row(
                modifier = GlanceModifier.fillMaxWidth(),
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                StatBlock(value = timeText, label = "Enfoque", emoji = "\u23F1")
                Spacer(modifier = GlanceModifier.width(16.dp))
                StatBlock(value = "$sessions", label = "Sesiones", emoji = "\u2705")
                Spacer(modifier = GlanceModifier.width(16.dp))
                StatBlock(value = "$streak", label = "Racha", emoji = "\uD83D\uDD25")
                Spacer(modifier = GlanceModifier.width(16.dp))
                StatBlock(value = "$completedTasks", label = "Tareas", emoji = "\uD83D\uDCCB")
            }
        }

        if (!isPro) {
            Box(
                modifier = GlanceModifier
                    .fillMaxSize()
                    .background(GlanceTheme.colors.widgetBackground.getColor(LocalContext.current).copy(alpha = 0.9f))
                    .cornerRadius(24.dp),
                contentAlignment = Alignment.Center,
            ) {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Text(
                        text = "\uD83D\uDD12",
                        style = TextStyle(fontSize = 24.sp),
                    )
                    Spacer(modifier = GlanceModifier.height(4.dp))
                    Text(
                        text = "PRO",
                        style = TextStyle(
                            fontSize = 14.sp,
                            fontWeight = FontWeight.Bold,
                            color = GlanceTheme.colors.primary,
                        ),
                    )
                }
            }
        }
    }
}

@Composable
private fun StatBlock(value: String, label: String, emoji: String) {
    Column(horizontalAlignment = Alignment.CenterHorizontally) {
        Text(
            text = emoji,
            style = TextStyle(fontSize = 18.sp),
        )
        Spacer(modifier = GlanceModifier.height(4.dp))
        Text(
            text = value,
            style = TextStyle(
                fontWeight = FontWeight.Bold,
                fontSize = 20.sp,
                color = GlanceTheme.colors.onSurface,
                textAlign = TextAlign.Center,
            ),
        )
        Text(
            text = label,
            style = TextStyle(
                fontSize = 10.sp,
                color = GlanceTheme.colors.onSurfaceVariant,
                textAlign = TextAlign.Center,
            ),
        )
    }
}

suspend fun updateStatsWidgetState(
    context: Context,
    totalMinutes: Int,
    sessions: Int,
    streak: Int,
    completedTasksToday: Int,
) {
    val manager = GlanceAppWidgetManager(context)
    val glanceIds = manager.getGlanceIds(DailyStatsWidget::class.java)
    glanceIds.forEach { glanceId ->
        updateAppWidgetState(context, PreferencesGlanceStateDefinition, glanceId) { prefs ->
            prefs.toMutablePreferences().apply {
                this[PREF_STATS_MINUTES] = totalMinutes
                this[PREF_STATS_SESSIONS] = sessions
                this[PREF_STATS_STREAK] = streak
                this[PREF_STATS_COMPLETED] = completedTasksToday
            }
        }
    }
}

class DailyStatsWidgetReceiver : GlanceAppWidgetReceiver() {
    override val glanceAppWidget: GlanceAppWidget = DailyStatsWidget()

    override fun onEnabled(context: Context) {
        super.onEnabled(context)
        // Trigger immediate data refresh when widget is first added
        WorkManager.getInstance(context).enqueue(
            OneTimeWorkRequestBuilder<WidgetRefreshWorker>().build(),
        )
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: android.appwidget.AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        super.onUpdate(context, appWidgetManager, appWidgetIds)
        // Refresh data from DB every time the system triggers an update (every 30 min)
        WorkManager.getInstance(context).enqueue(
            OneTimeWorkRequestBuilder<WidgetRefreshWorker>().build(),
        )
    }
}
