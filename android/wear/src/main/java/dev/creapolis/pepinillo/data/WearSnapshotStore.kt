package dev.creapolis.pepinillo.data

import android.content.Context

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
    private const val KEY_LAST_SYNC_AT_MILLIS = "last_sync_at_millis"
    private const val KEY_LINKED_TASK_ID = "linked_task_id"
    private const val KEY_LINKED_TASK_NAME = "linked_task_name"
    private const val KEY_COMPLETED_SESSIONS = "completed_sessions"
    private const val KEY_THEME_ID = "theme_id"
    private const val KEY_POMODORO_COLOR = "pomodoro_color"
    private const val KEY_FLOWTIME_COLOR = "flowtime_color"
    private const val KEY_TIMEBLOCK_COLOR = "timeblock_color"
    private const val KEY_STOPWATCH_COLOR = "stopwatch_color"
    private const val KEY_STREAK_COLOR = "streak_color"
    private const val KEY_PHASE_END_EPOCH_MS = "phase_end_epoch_ms"
    private const val KEY_TOTAL_DURATION_MS = "total_duration_ms"
    private const val KEY_IS_PRO = "is_pro"

    fun bootstrap(context: Context) {
        WearDataStore.updateTimer(readTimerState(context))
        WearDataStore.updateTasks(readTasks(context))
        WearDataStore.updateStats(readStats(context))
        WearDataStore.updateLastSyncAtMillis(readLastSyncAtMillis(context))
        WearDataStore.updateThemeColors(readThemeColors(context))
        WearDataStore.updateIsPro(readIsPro(context))
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
            .putString(KEY_LINKED_TASK_ID, state.linkedTaskId)
            .putString(KEY_LINKED_TASK_NAME, state.linkedTaskName)
            .putInt(KEY_COMPLETED_SESSIONS, state.completedSessions)
            .putLong(KEY_PHASE_END_EPOCH_MS, state.phaseEndEpochMs)
            .putLong(KEY_TOTAL_DURATION_MS, state.totalDurationMs)
            .apply()
    }

    fun persistTasks(context: Context, tasks: List<WearTask>) {
        val tasksJson = WearSnapshotTaskCodec.serialize(tasks)

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

    fun persistLastSyncAtMillis(context: Context, value: Long) {
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .putLong(KEY_LAST_SYNC_AT_MILLIS, value)
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
            linkedTaskId = prefs.getString(KEY_LINKED_TASK_ID, null),
            linkedTaskName = prefs.getString(KEY_LINKED_TASK_NAME, null),
            completedSessions = prefs.getInt(KEY_COMPLETED_SESSIONS, 0),
            phaseEndEpochMs = prefs.getLong(KEY_PHASE_END_EPOCH_MS, 0L),
            totalDurationMs = prefs.getLong(KEY_TOTAL_DURATION_MS, 0L),
        )
    }

    fun readTasks(context: Context): List<WearTask> {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val tasksJson = prefs.getString(KEY_TASKS_JSON, "[]") ?: "[]"
        return WearSnapshotTaskCodec.deserialize(tasksJson)
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

    fun readLastSyncAtMillis(context: Context): Long? {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        return if (prefs.contains(KEY_LAST_SYNC_AT_MILLIS)) {
            prefs.getLong(KEY_LAST_SYNC_AT_MILLIS, 0L)
        } else {
            null
        }
    }

    fun persistThemeColors(context: Context, colors: WearThemeColors) {
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .putString(KEY_THEME_ID, colors.themeId)
            .putLong(KEY_POMODORO_COLOR, colors.pomodoroColor)
            .putLong(KEY_FLOWTIME_COLOR, colors.flowtimeColor)
            .putLong(KEY_TIMEBLOCK_COLOR, colors.timeBlockColor)
            .putLong(KEY_STOPWATCH_COLOR, colors.stopwatchColor)
            .putLong(KEY_STREAK_COLOR, colors.streakColor)
            .apply()
    }

    fun readThemeColors(context: Context): WearThemeColors {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        return WearThemeColors(
            themeId = prefs.getString(KEY_THEME_ID, "classic") ?: "classic",
            pomodoroColor = prefs.getLong(KEY_POMODORO_COLOR, 0xFFE84D3D),
            flowtimeColor = prefs.getLong(KEY_FLOWTIME_COLOR, 0xFF3385EB),
            timeBlockColor = prefs.getLong(KEY_TIMEBLOCK_COLOR, 0xFF8F45DD),
            stopwatchColor = prefs.getLong(KEY_STOPWATCH_COLOR, 0xFF2DB870),
            streakColor = prefs.getLong(KEY_STREAK_COLOR, 0xFFFF991A),
        )
    }

    fun persistIsPro(context: Context, isPro: Boolean) {
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .putBoolean(KEY_IS_PRO, isPro)
            .apply()
    }

    fun readIsPro(context: Context): Boolean {
        return context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .getBoolean(KEY_IS_PRO, false)
    }
    }