package dev.creapolis.pepinillo.data

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject

object WearSnapshotStore {
    private const val PREFS_NAME = "wear_snapshot"
    private const val KEY_MODE = "mode"
    private const val KEY_PHASE = "phase"
    private const val KEY_STATUS = "status"
    private const val KEY_DISPLAY_TIME = "display_time"
    private const val KEY_PHASE_LABEL = "phase_label"
    private const val KEY_PROGRESS = "progress"
    private const val KEY_IS_CONNECTED = "is_connected"
    private const val KEY_TASKS_JSON = "tasks_json"
    private const val KEY_TOTAL_MINUTES = "total_minutes"
    private const val KEY_SESSIONS = "sessions"
    private const val KEY_STREAK = "streak"
    private const val KEY_COMPLETED_TASKS = "completed_tasks"

    fun bootstrap(context: Context) {
        WearDataStore.updateTimer(readTimerState(context))
        WearDataStore.updateTasks(readTasks(context))
        WearDataStore.updateStats(readStats(context))
    }

    fun persistTimerState(context: Context, state: WearTimerState) {
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .putString(KEY_MODE, state.mode)
            .putString(KEY_PHASE, state.phase)
            .putString(KEY_STATUS, state.status)
            .putString(KEY_DISPLAY_TIME, state.displayTime)
            .putString(KEY_PHASE_LABEL, state.phaseLabel)
            .putFloat(KEY_PROGRESS, state.progress)
            .putBoolean(KEY_IS_CONNECTED, state.isConnected)
            .apply()
    }

    fun persistTasks(context: Context, tasks: List<WearTask>) {
        val tasksJson = JSONArray().apply {
            tasks.forEach { task ->
                put(
                    JSONObject().apply {
                        put("id", task.id)
                        put("title", task.title)
                        put("energyEmoji", task.energyEmoji)
                        put("pomodoroProgress", task.pomodoroProgress)
                    },
                )
            }
        }.toString()

        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .putString(KEY_TASKS_JSON, tasksJson)
            .apply()
    }

    fun persistStats(context: Context, stats: WearStatsState) {
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .putInt(KEY_TOTAL_MINUTES, stats.totalMinutes)
            .putInt(KEY_SESSIONS, stats.sessions)
            .putInt(KEY_STREAK, stats.streak)
            .putInt(KEY_COMPLETED_TASKS, stats.completedTasks)
            .apply()
    }

    fun readTimerState(context: Context): WearTimerState {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        return WearTimerState(
            mode = prefs.getString(KEY_MODE, "Pomodoro") ?: "Pomodoro",
            phase = prefs.getString(KEY_PHASE, "Work") ?: "Work",
            status = prefs.getString(KEY_STATUS, "Disconnected") ?: "Disconnected",
            displayTime = prefs.getString(KEY_DISPLAY_TIME, "00:00") ?: "00:00",
            phaseLabel = prefs.getString(KEY_PHASE_LABEL, "Sincronizando") ?: "Sincronizando",
            progress = prefs.getFloat(KEY_PROGRESS, 0f),
            isConnected = prefs.getBoolean(KEY_IS_CONNECTED, false),
        )
    }

    fun readTasks(context: Context): List<WearTask> {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val tasksJson = prefs.getString(KEY_TASKS_JSON, "[]") ?: "[]"
        return runCatching {
            val arr = JSONArray(tasksJson)
            (0 until arr.length()).map { idx ->
                val obj = arr.getJSONObject(idx)
                WearTask(
                    id = obj.optString("id"),
                    title = obj.optString("title"),
                    energyEmoji = obj.optString("energyEmoji", "⚡"),
                    pomodoroProgress = obj.optString("pomodoroProgress", ""),
                )
            }
        }.getOrDefault(emptyList())
    }

    fun readStats(context: Context): WearStatsState {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        return WearStatsState(
            totalMinutes = prefs.getInt(KEY_TOTAL_MINUTES, 0),
            sessions = prefs.getInt(KEY_SESSIONS, 0),
            streak = prefs.getInt(KEY_STREAK, 0),
            completedTasks = prefs.getInt(KEY_COMPLETED_TASKS, 0),
        )
    }
}