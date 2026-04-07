package dev.creapolis.pepinillo.data

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import org.json.JSONArray

object WearDataStore {
    private val _timerState = MutableStateFlow(WearTimerState())
    private val _tasks = MutableStateFlow(emptyList<WearTask>())
    private val _stats = MutableStateFlow(WearStatsState())
    private val _isPro = MutableStateFlow(false)

    private val _themeColors = MutableStateFlow(WearThemeColors())
    val themeColors: StateFlow<WearThemeColors> = _themeColors

    private val _pendingCommandCount = MutableStateFlow(0)
    private val _lastSyncAtMillis = MutableStateFlow<Long?>(null)
    private val _diagnostics = MutableStateFlow(WearDiagnosticsState())

    val timerState = _timerState.asStateFlow()
    val tasks = _tasks.asStateFlow()
    val stats = _stats.asStateFlow()
    val isPro = _isPro.asStateFlow()
    val pendingCommandCount = _pendingCommandCount.asStateFlow()
    val lastSyncAtMillis = _lastSyncAtMillis.asStateFlow()
    val diagnostics = _diagnostics.asStateFlow()

    fun updatePendingCount(count: Int) {
        _pendingCommandCount.value = count
    }

    fun updateLastSyncAtMillis(value: Long?) {
        _lastSyncAtMillis.value = value
    }

    fun recordSyncEvent() {
        _diagnostics.value = _diagnostics.value.copy(syncEvents = _diagnostics.value.syncEvents + 1)
    }

    fun recordSyncFailure(message: String) {
        _diagnostics.value = _diagnostics.value.copy(
            syncFailures = _diagnostics.value.syncFailures + 1,
            lastError = message,
        )
    }

    fun recordFlushAttempt(count: Int) {
        if (count <= 0) return
        _diagnostics.value = _diagnostics.value.copy(
            flushAttempts = _diagnostics.value.flushAttempts + count,
        )
    }

    fun recordFlushFailures(count: Int, message: String? = null) {
        if (count <= 0 && message == null) return
        _diagnostics.value = _diagnostics.value.copy(
            flushFailures = _diagnostics.value.flushFailures + count.coerceAtLeast(0),
            lastError = message ?: _diagnostics.value.lastError,
        )
    }

    fun updateConnectedNodes(count: Int, names: List<String>) {
        _diagnostics.value = _diagnostics.value.copy(
            connectedNodeCount = count.coerceAtLeast(0),
            connectedNodeNames = names.filter { it.isNotBlank() },
        )
    }

    fun resetDiagnostics() {
        _diagnostics.value = WearDiagnosticsState()
    }

    fun updateTimer(newState: WearTimerState) {
        _timerState.value = newState
    }

    fun updateTasksFromJson(tasksJson: String) {
        val parsed = runCatching {
            val arr = JSONArray(tasksJson)
            (0 until arr.length()).map { i ->
                val obj = arr.getJSONObject(i)
                WearTask(
                    id = obj.getString("id"),
                    title = obj.getString("title"),
                    energyEmoji = obj.optString("energyEmoji", ""),
                    pomodoroProgress = obj.optString("pomodoroProgress", ""),
                )
            }
        }.getOrElse { e ->
            android.util.Log.w("WearDataStore", "Failed to parse tasks JSON (len=${tasksJson.length})", e)
            emptyList()
        }
        android.util.Log.d("WearDataStore", "updateTasksFromJson: parsed ${parsed.size} tasks")
        _tasks.value = parsed
    }

    fun updateTasks(newTasks: List<WearTask>) {
        _tasks.value = newTasks
    }

    fun updateStats(newState: WearStatsState) {
        _stats.value = newState
    }

    fun updateThemeColors(colors: WearThemeColors) {
        _themeColors.value = colors
    }

    fun updateIsPro(isPro: Boolean) {
        _isPro.value = isPro
    }
}

data class WearTimerState(
    val mode: String = "Pomodoro",
    val phase: String = "Work",
    val status: String = "Idle",
    val displayTime: String = "25:00",
    val phaseLabel: String = "Listo",
    val progress: Float = 1f,
    val isConnected: Boolean = false,
    val linkedTaskId: String? = null,
    val linkedTaskName: String? = null,
    val completedSessions: Int = 0,
    /** Epoch millis when the current phase ends (only meaningful when status == Running). */
    val phaseEndEpochMs: Long = 0L,
    /** Total duration of the current phase in milliseconds. */
    val totalDurationMs: Long = 0L,
)

data class WearTask(
    val id: String,
    val title: String,
    val energyEmoji: String,
    val pomodoroProgress: String,
)

data class WearStatsState(
    val totalMinutes: Int = 0,
    val sessions: Int = 0,
    val streak: Int = 0,
    val completedTasks: Int = 0,
)

data class WearDiagnosticsState(
    val syncEvents: Int = 0,
    val syncFailures: Int = 0,
    val flushAttempts: Int = 0,
    val flushFailures: Int = 0,
    val connectedNodeCount: Int = 0,
    val connectedNodeNames: List<String> = emptyList(),
    val lastError: String? = null,
)

data class WearThemeColors(
    val themeId: String = "classic",
    val pomodoroColor: Long = 0xFFE84D3D,
    val flowtimeColor: Long = 0xFF3385EB,
    val timeBlockColor: Long = 0xFF8F45DD,
    val stopwatchColor: Long = 0xFF2DB870,
    val streakColor: Long = 0xFFFF991A,
)
