package dev.creapolis.pepinillo.data

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import org.json.JSONArray

object WearDataStore {
    private val _timerState = MutableStateFlow(WearTimerState())
    private val _tasks = MutableStateFlow(emptyList<WearTask>())
    private val _stats = MutableStateFlow(WearStatsState())

    private val _pendingCommandCount = MutableStateFlow(0)

    val timerState = _timerState.asStateFlow()
    val tasks = _tasks.asStateFlow()
    val stats = _stats.asStateFlow()
    val pendingCommandCount = _pendingCommandCount.asStateFlow()

    fun updatePendingCount(count: Int) {
        _pendingCommandCount.value = count
    }

    fun updateTimer(newState: WearTimerState) {
        _timerState.value = newState
    }

    fun updateTasksFromJson(tasksJson: String) {
        val parsed = runCatching {
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
        _tasks.value = parsed
    }

    fun updateTasks(newTasks: List<WearTask>) {
        _tasks.value = newTasks
    }

    fun updateStats(newState: WearStatsState) {
        _stats.value = newState
    }
}

data class WearTimerState(
    val mode: String = "Pomodoro",
    val phase: String = "Work",
    val status: String = "Disconnected",
    val displayTime: String = "00:00",
    val phaseLabel: String = "Sincronizando",
    val progress: Float = 0f,
    val isConnected: Boolean = false,
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
