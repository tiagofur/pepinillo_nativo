package dev.creapolis.pepinillo.widget

import android.content.Context
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
import androidx.glance.layout.wrapContentHeight
import androidx.glance.text.FontWeight
import androidx.glance.text.Text
import androidx.glance.text.TextAlign
import androidx.glance.text.TextStyle
import androidx.glance.unit.ColorProvider
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.workDataOf
import dev.creapolis.pepinillo.MainActivity
import dev.creapolis.pepinillo.R
import dev.creapolis.pepinillo.widget.CompleteTaskWorker
import org.json.JSONArray
import org.json.JSONObject

// ─────────────────────────── Data model ───────────────────────────────────

data class WidgetTask(
    val id: String,
    val title: String,
    val energyEmoji: String,
    val pomodoroProgress: String, // e.g. "2/4 🍅" or "" if no estimate
)

// ─────────────────────────── State manager ────────────────────────────────

object WidgetTaskStateManager {

    private const val PREFS = "pepinillo_tasks_widget"
    private const val KEY_TASKS = "tasks_json"
    private const val KEY_COMPLETED_TODAY = "completed_today"
    private const val MAX_WIDGET_TASKS = 5

    private fun prefs(ctx: Context): SharedPreferences =
        ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun updateTasks(context: Context, tasks: List<WidgetTask>, completedToday: Int = readCompletedToday(context)) {
        val jsonArray = JSONArray()
        tasks.take(MAX_WIDGET_TASKS).forEach { task ->
            jsonArray.put(JSONObject().apply {
                put("id", task.id)
                put("title", task.title)
                put("energyEmoji", task.energyEmoji)
                put("pomodoroProgress", task.pomodoroProgress)
            })
        }
        prefs(context).edit()
            .putString(KEY_TASKS, jsonArray.toString())
            .putInt(KEY_COMPLETED_TODAY, completedToday)
            .apply()
    }

    fun readTasks(context: Context): List<WidgetTask> {
        val json = prefs(context).getString(KEY_TASKS, "[]") ?: "[]"
        return try {
            val arr = JSONArray(json)
            (0 until arr.length()).map { i ->
                val obj = arr.getJSONObject(i)
                WidgetTask(
                    id = obj.getString("id"),
                    title = obj.getString("title"),
                    energyEmoji = obj.optString("energyEmoji", "⚡"),
                    pomodoroProgress = obj.optString("pomodoroProgress", ""),
                )
            }
        } catch (_: Exception) {
            emptyList()
        }
    }

    fun readCompletedToday(context: Context): Int =
        prefs(context).getInt(KEY_COMPLETED_TODAY, 0)
}

// ─────────────────────────── Widget ───────────────────────────────────────

class TasksWidget : GlanceAppWidget() {
    override suspend fun provideGlance(context: Context, id: GlanceId) {
        provideContent {
            GlanceTheme {
                TasksContent(context)
            }
        }
    }
}

@Composable
private fun TasksContent(context: Context) {
    val tasks = WidgetTaskStateManager.readTasks(context)

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
                text = "📋 Tareas",
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
            tasks.forEach { task ->
                TaskRow(task)
                Spacer(modifier = GlanceModifier.height(6.dp))
            }
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
                text = "✓",
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
}
