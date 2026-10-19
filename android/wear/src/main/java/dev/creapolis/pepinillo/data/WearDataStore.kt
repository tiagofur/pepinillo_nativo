package dev.creapolis.pepinillo.data

import android.util.Log
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import org.json.JSONArray

object WearDataStore {
    private const val TAG = "WearDataStore"

    private val _timerState = MutableStateFlow(WearTimerState())
    private val _tasks = MutableStateFlow(emptyList<WearTask>())
    private val _stats = MutableStateFlow(WearStatsState())
    private val _isPro = MutableStateFlow(false)

    private val _themeColors = MutableStateFlow(WearThemeColors())
    val themeColors: StateFlow<WearThemeColors> = _themeColors

    private val _pendingCommandCount = MutableStateFlow(0)
    private val _lastSyncAtMillis = MutableStateFlow<Long?>(null)
    private val _diagnostics = MutableStateFlow(WearDiagnosticsState())

    /**
     * Monotonic counter bumped ONLY when an authoritative timer state pushed by the
     * phone is applied (a PATH_TIMER DataItem arriving via WearSyncListenerService or
     * WearDataFetcher). [dev.creapolis.pepinillo.viewmodel.WearViewModel] optimistic
     * updates must NOT bump it — WearCommandWatchdog uses it to tell a phone-confirmed
     * command apart from locally-applied optimistic state (E2).
     */
    private val _remoteTimerRevisions = MutableStateFlow(0L)
    val remoteTimerRevisions: StateFlow<Long> = _remoteTimerRevisions.asStateFlow()

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

    /** Bumped by remote timer DataItem application sites — see [remoteTimerRevisions]. */
    fun recordRemoteTimerRevision() {
        _remoteTimerRevisions.value += 1L
    }

    /** Test isolation helper, mirrors [resetDiagnostics]. */
    fun resetRemoteTimerRevisions() {
        _remoteTimerRevisions.value = 0L
    }

    fun updateTimer(newState: WearTimerState) {
        _timerState.value = newState
    }

    /**
     * Zeros the in-memory `completedSessions` on a day change. Atomic copy avoids
     * the read-modify-write race a caller would otherwise have to perform against
     * [timerState]. Does not touch the persisted snapshot (callers do that via
     * [WearSnapshotStore]).
     */
    fun resetCompletedSessions() {
        _timerState.value = _timerState.value.copy(completedSessions = 0)
    }

    fun updateTasksFromJson(tasksJson: String) {
        val parsed = runCatching {
            parseTasksJson(tasksJson)
        }.getOrElse { e ->
            // P2(g): android.util.Log instead of println/System.err. runCatching because
            // android.util.Log is stubbed in JVM unit tests (WearDataStoreTest).
            runCatching { Log.w(TAG, "Failed to parse tasks JSON (len=${tasksJson.length}): ${e.message}") }
            emptyList()
        }
        runCatching { Log.d(TAG, "Parsed ${parsed.size} tasks") }
        _tasks.value = parsed
    }

    private fun parseTasksJson(tasksJson: String): List<WearTask> {
        val trimmed = tasksJson.trim()
        if (trimmed.isBlank() || trimmed == "[]") return emptyList()

        // Use org.json (bundled in the Android runtime) instead of a hand-rolled regex
        // parser: the previous Regex("\\{[^{}]*}") broke on any field value that itself
        // contained a `}` character. JSONArray tolerates arbitrary string contents.
        val array = JSONArray(trimmed)
        val result = ArrayList<WearTask>(array.length())
        for (i in 0 until array.length()) {
            val obj = array.optJSONObject(i) ?: continue
            // optString returns "" for missing OR JSON-null fields, which matches the
            // previous regex fallback semantics for energy/progress.
            val id = obj.optString("id")
            val title = obj.optString("title")
            // Skip entries that lack a usable id/title (parity with old behaviour where
            // null id/title caused the entry to be dropped).
            if (id.isEmpty() || title.isEmpty()) continue
            result +=
                WearTask(
                    id = id,
                    title = title,
                    energyEmoji = obj.optString("energyEmoji"),
                    pomodoroProgress = obj.optString("pomodoroProgress"),
                )
        }
        return result
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
    val sessionsBeforeLongBreak: Int = 4,
    /** Epoch millis when the current phase ends (countdown modes, status == Running). */
    val phaseEndEpochMs: Long = 0L,
    /** Epoch millis when the current phase started (count-up modes, status == Running). */
    val phaseStartEpochMs: Long = 0L,
    /** Remaining countdown ms or elapsed ms at pause — used to resume without resetting. */
    val remainingDurationMs: Long = 0L,
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
