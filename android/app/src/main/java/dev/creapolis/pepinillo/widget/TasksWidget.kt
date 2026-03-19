package dev.creapolis.pepinillo.widget

import android.content.Context
import androidx.compose.runtime.Composable
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.intPreferencesKey
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
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.workDataOf
import dagger.hilt.android.EntryPointAccessors
import dev.creapolis.pepinillo.MainActivity
import dev.creapolis.pepinillo.R
import dev.creapolis.pepinillo.data.sync.WidgetRefreshWorker
import dev.creapolis.pepinillo.feature.tasks.model.EnergyLevel
import kotlinx.coroutines.flow.first
import org.json.JSONArray
import org.json.JSONObject

// ─────────────────────────── Data model ───────────────────────────────────

data class WidgetTask(
    val id: String,
    val title: String,
    val energyEmoji: String,
    val pomodoroProgress: String, // e.g. "2/4 🍅" or "" if no estimate
) {
    companion object {
        /** Convert a domain Task to a WidgetTask. Shared by TaskRepository, PhoneWearListenerService, etc. */
        fun fromTask(task: dev.creapolis.pepinillo.feature.tasks.model.Task): WidgetTask {
            val energyEmoji = when (task.energyLevel) {
                dev.creapolis.pepinillo.feature.tasks.model.EnergyLevel.Deep -> "\uD83D\uDD25"
                dev.creapolis.pepinillo.feature.tasks.model.EnergyLevel.Regular -> "\u26A1"
                dev.creapolis.pepinillo.feature.tasks.model.EnergyLevel.Light -> "\uD83D\uDCA7"
            }
            val pomodoroProgress = if (task.estimatedPomodoros > 0) {
                "${task.completedPomodoros}/${task.estimatedPomodoros} \uD83C\uDF45"
            } else ""
            return WidgetTask(
                id = task.id,
                title = task.title,
                energyEmoji = energyEmoji,
                pomodoroProgress = pomodoroProgress,
            )
        }
    }
}

// ─────────────────────────── Glance preference keys ──────────────────────

private val PREF_TASKS_JSON = stringPreferencesKey("tasks_json")
private val PREF_COMPLETED_TODAY = intPreferencesKey("completed_today")
private val PREF_LINKED_TASK_ID = stringPreferencesKey("linked_task_id")
private const val MAX_WIDGET_TASKS = 5

private fun tasksFromJson(json: String?): List<WidgetTask> {
    if (json.isNullOrBlank()) return emptyList()
    return try {
        val arr = JSONArray(json)
        (0 until arr.length()).map { i ->
            val obj = arr.getJSONObject(i)
            WidgetTask(
                id = obj.getString("id"),
                title = obj.getString("title"),
                energyEmoji = obj.optString("energyEmoji", "\u26A1"),
                pomodoroProgress = obj.optString("pomodoroProgress", ""),
            )
        }
    } catch (_: Exception) {
        emptyList()
    }
}

private fun tasksToJson(tasks: List<WidgetTask>): String {
    val jsonArray = JSONArray()
    tasks.take(MAX_WIDGET_TASKS).forEach { task ->
        jsonArray.put(JSONObject().apply {
            put("id", task.id)
            put("title", task.title)
            put("energyEmoji", task.energyEmoji)
            put("pomodoroProgress", task.pomodoroProgress)
        })
    }
    return jsonArray.toString()
}

// ─────────────────────────── State manager ────────────────────────────────

object WidgetTaskStateManager {

    suspend fun updateTasks(context: Context, tasks: List<WidgetTask>, completedToday: Int = 0) {
        val manager = GlanceAppWidgetManager(context)
        val glanceIds = manager.getGlanceIds(TasksWidget::class.java)
        val json = tasksToJson(tasks)
        glanceIds.forEach { glanceId ->
            updateAppWidgetState(context, PreferencesGlanceStateDefinition, glanceId) { prefs ->
                prefs.toMutablePreferences().apply {
                    this[PREF_TASKS_JSON] = json
                    this[PREF_COMPLETED_TODAY] = completedToday
                }
            }
        }
        TasksWidget().updateAll(context)
    }

    suspend fun updateLinkedTaskId(context: Context, taskId: String?) {
        val manager = GlanceAppWidgetManager(context)
        val glanceIds = manager.getGlanceIds(TasksWidget::class.java)
        glanceIds.forEach { glanceId ->
            updateAppWidgetState(context, PreferencesGlanceStateDefinition, glanceId) { prefs ->
                prefs.toMutablePreferences().apply {
                    if (taskId != null) {
                        this[PREF_LINKED_TASK_ID] = taskId
                    } else {
                        remove(PREF_LINKED_TASK_ID)
                    }
                }
            }
        }
        TasksWidget().updateAll(context)
    }
}

// ─────────────────────────── Widget ───────────────────────────────────────

class TasksWidget : GlanceAppWidget() {
    override val stateDefinition = PreferencesGlanceStateDefinition

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        // Fetch fresh data directly from DB so widget never shows stale/empty state
        try {
            val entryPoint = EntryPointAccessors.fromApplication(
                context.applicationContext, WidgetEntryPoint::class.java,
            )
            val taskRepo = entryPoint.taskRepository()
            val activeTasks = taskRepo.getActiveTasks().first()
            val widgetTasks = activeTasks.take(MAX_WIDGET_TASKS).map { task ->
                val energyEmoji = when (task.energyLevel) {
                    EnergyLevel.Deep -> "\uD83D\uDD25"
                    EnergyLevel.Light -> "\uD83D\uDCA7"
                    else -> "\u26A1"
                }
                val pomodoroProgress = if (task.estimatedPomodoros > 0) {
                    "${task.completedPomodoros}/${task.estimatedPomodoros} \uD83C\uDF45"
                } else ""
                WidgetTask(
                    id = task.id,
                    title = task.title,
                    energyEmoji = energyEmoji,
                    pomodoroProgress = pomodoroProgress,
                )
            }
            updateAppWidgetState(context, PreferencesGlanceStateDefinition, id) { prefs ->
                prefs.toMutablePreferences().apply {
                    this[PREF_TASKS_JSON] = tasksToJson(widgetTasks)
                }
            }
        } catch (_: Exception) {
            // Fallback: render with whatever is already in the DataStore
        }

        provideContent {
            GlanceTheme {
                TasksContent()
            }
        }
    }
}

@Composable
private fun TasksContent() {
    val prefs = currentState<Preferences>()
    val tasks = tasksFromJson(prefs[PREF_TASKS_JSON])
    val linkedTaskId = prefs[PREF_LINKED_TASK_ID]

    Column(
        modifier = GlanceModifier
            .fillMaxSize()
            .background(GlanceTheme.colors.widgetBackground)
            .cornerRadius(24.dp)
            .padding(14.dp)
            .clickable(actionStartActivity<MainActivity>()),
    ) {
        // Header row
        Row(
            modifier = GlanceModifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                text = "\uD83D\uDCCB Tareas (${tasks.size})",
                style = TextStyle(
                    fontSize = 13.sp,
                    fontWeight = FontWeight.Bold,
                    color = GlanceTheme.colors.primary,
                ),
            )
        }

        Spacer(modifier = GlanceModifier.height(8.dp))

        if (tasks.isEmpty()) {
            EmptyState()
        } else {
            // Show linked task first with highlight (like Wear's primary chip)
            val linkedTask = linkedTaskId?.let { id -> tasks.find { it.id == id } }
            val otherTasks = tasks.filter { it.id != linkedTaskId }

            if (linkedTask != null) {
                LinkedTaskRow(linkedTask)
                Spacer(modifier = GlanceModifier.height(6.dp))
            }

            otherTasks.forEach { task ->
                TaskRow(task)
                Spacer(modifier = GlanceModifier.height(6.dp))
            }
        }
    }
}

@Composable
private fun LinkedTaskRow(task: WidgetTask) {
    Row(
        modifier = GlanceModifier
            .fillMaxWidth()
            .background(GlanceTheme.colors.primary)
            .cornerRadius(12.dp)
            .padding(horizontal = 10.dp, vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            text = "\u25B6",
            style = TextStyle(
                fontSize = 12.sp,
                color = ColorProvider(R.color.widget_white),
            ),
        )
        Spacer(modifier = GlanceModifier.width(8.dp))
        Column(modifier = GlanceModifier.defaultWeight()) {
            Text(
                text = task.title,
                style = TextStyle(
                    fontSize = 13.sp,
                    fontWeight = FontWeight.Bold,
                    color = ColorProvider(R.color.widget_white),
                ),
                maxLines = 1,
            )
            Text(
                text = "\uD83C\uDF45 En progreso${if (task.pomodoroProgress.isNotEmpty()) " \u00B7 ${task.pomodoroProgress}" else ""}",
                style = TextStyle(
                    fontSize = 10.sp,
                    color = ColorProvider(R.color.widget_white),
                ),
            )
        }
    }
}

@Composable
private fun TaskRow(task: WidgetTask) {
    Row(
        modifier = GlanceModifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        // Complete button
        Box(
            modifier = GlanceModifier
                .background(ColorProvider(R.color.widget_stop_bg))
                .cornerRadius(12.dp)
                .clickable(
                    actionRunCallback<CompleteTaskWidgetAction>(
                        actionParametersOf(taskIdParam to task.id),
                    ),
                )
                .padding(horizontal = 8.dp, vertical = 6.dp),
            contentAlignment = Alignment.Center,
        ) {
            Text(
                text = "\u2713",
                style = TextStyle(
                    fontSize = 12.sp,
                    fontWeight = FontWeight.Bold,
                    color = ColorProvider(R.color.widget_stop_text),
                ),
            )
        }

        Spacer(modifier = GlanceModifier.width(8.dp))

        // Task info
        Column(modifier = GlanceModifier.defaultWeight()) {
            Text(
                text = "${task.energyEmoji} ${task.title}",
                style = TextStyle(
                    fontSize = 12.sp,
                    color = GlanceTheme.colors.onSurface,
                ),
                maxLines = 1,
            )
            if (task.pomodoroProgress.isNotEmpty()) {
                Text(
                    text = task.pomodoroProgress,
                    style = TextStyle(
                        fontSize = 10.sp,
                        color = GlanceTheme.colors.onSurfaceVariant,
                    ),
                )
            }
        }
    }
}

@Composable
private fun EmptyState() {
    Column(
        modifier = GlanceModifier.fillMaxSize(),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            text = "No hay tareas activas",
            style = TextStyle(
                fontSize = 12.sp,
                color = GlanceTheme.colors.onSurfaceVariant,
                textAlign = TextAlign.Center,
            ),
        )
        Spacer(modifier = GlanceModifier.height(6.dp))
        Box(
            modifier = GlanceModifier
                .background(GlanceTheme.colors.primary)
                .cornerRadius(16.dp)
                .clickable(actionStartActivity<MainActivity>())
                .padding(horizontal = 16.dp, vertical = 8.dp),
            contentAlignment = Alignment.Center,
        ) {
            Text(
                text = "+ Nueva tarea",
                style = TextStyle(
                    fontSize = 12.sp,
                    fontWeight = FontWeight.Medium,
                    color = ColorProvider(R.color.widget_white),
                ),
            )
        }
    }
}

// ─────────────────────────── Actions ──────────────────────────────────────

val taskIdParam = ActionParameters.Key<String>("task_id")

class CompleteTaskWidgetAction : ActionCallback {
    override suspend fun onAction(context: Context, glanceId: GlanceId, parameters: ActionParameters) {
        val taskId = parameters[taskIdParam] ?: return
        // Dispatch to CompleteTaskWorker so Hilt/Room are available
        WorkManager.getInstance(context).enqueue(
            OneTimeWorkRequestBuilder<CompleteTaskWorker>()
                .setInputData(workDataOf(CompleteTaskWorker.KEY_TASK_ID to taskId))
                .build(),
        )
    }
}

// ─────────────────────────── Receiver ─────────────────────────────────────

class TasksWidgetReceiver : GlanceAppWidgetReceiver() {
    override val glanceAppWidget: GlanceAppWidget = TasksWidget()

    override fun onEnabled(context: Context) {
        super.onEnabled(context)
        // Load tasks from DB immediately when widget is first added
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
        // Refresh data when system triggers update
        WorkManager.getInstance(context).enqueue(
            OneTimeWorkRequestBuilder<WidgetRefreshWorker>().build(),
        )
    }
}
