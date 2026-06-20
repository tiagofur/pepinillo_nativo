package dev.creapolis.pepinillo.viewmodel

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.google.android.gms.wearable.Wearable
import dev.creapolis.pepinillo.data.WearDataStore
import dev.creapolis.pepinillo.data.WearMessageSender
import dev.creapolis.pepinillo.data.WearSnapshotStore
import dev.creapolis.pepinillo.data.WearTimerState
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.tasks.await

import dev.creapolis.pepinillo.service.WearFocusService

class WearViewModel(application: Application) : AndroidViewModel(application) {
    private val sender = WearMessageSender(application)

    val timerState = WearDataStore.timerState
    val tasks = WearDataStore.tasks
    val stats = WearDataStore.stats
    val isPro = WearDataStore.isPro
    val pendingCommandCount = WearDataStore.pendingCommandCount
    val lastSyncAtMillis = WearDataStore.lastSyncAtMillis
    val diagnostics = WearDataStore.diagnostics

    private suspend fun sendSafely(tag: String, action: suspend () -> Boolean) {
        runCatching { action() }
            .onFailure { error ->
                WearDataStore.recordSyncFailure("$tag: ${error.javaClass.simpleName}")
            }
    }

    init {
        viewModelScope.launch {
            while (true) {
                refreshNodeDiagnostics()
                delay(5_000)
            }
        }
    }

    /**
     * Compute the optimistic epoch-ms moment the current phase should end at, so the local
     * countdown loop in TimerScreen has something to render before the phone pushes the
     * authoritative value.
     *
     * Reuse the last known duration when present; otherwise pick a sensible default per
     * phase. The phone corrects this on the next sync push.
     */
    private fun optimisticPhaseEndMs(current: WearTimerState): Long {
        val durationMs = current.totalDurationMs.takeIf { it > 0 }
            ?: defaultPhaseDurationMs(current.mode, current.phase)
        return System.currentTimeMillis() + durationMs
    }

    private fun defaultPhaseDurationMs(mode: String, phase: String): Long {
        // Pomodoro defaults: 25/5/15 minutes. Other modes default to 25 minutes too — this
        // is only a placeholder so the ring moves until the phone's authoritative push.
        val minutes = when (phase) {
            "ShortBreak" -> 5L
            "LongBreak" -> 15L
            else -> 25L
        }
        return minutes * 60L * 1000L
    }

    /** Update [WearDataStore] AND mirror to [WearSnapshotStore] so process death doesn't
     *  revert the user's last action on cold restart. */
    private fun applyTimerOptimistically(newState: WearTimerState) {
        WearDataStore.updateTimer(newState)
        WearSnapshotStore.persistTimerState(getApplication(), newState)
    }

    private fun applyTasksOptimistically(newTasks: List<dev.creapolis.pepinillo.data.WearTask>) {
        WearDataStore.updateTasks(newTasks)
        WearSnapshotStore.persistTasks(getApplication(), newTasks)
    }

    fun startTimer(mode: String) {
        // Optimistic UI: show Running immediately with a usable countdown end.
        val current = timerState.value
        val durationMs = current.totalDurationMs.takeIf { it > 0 }
            ?: defaultPhaseDurationMs(mode, "Work")
        applyTimerOptimistically(
            current.copy(
                mode = mode,
                phase = "Work",
                status = "Running",
                phaseLabel = "Focus",
                progress = 0f,
                totalDurationMs = durationMs,
                phaseEndEpochMs = System.currentTimeMillis() + durationMs,
            ),
        )
        WearFocusService.start(getApplication())
        viewModelScope.launch {
            sendSafely("start_timer") { sender.startTimer(mode) }
        }
    }

    fun pauseTimer() {
        // Optimistic UI: show Paused immediately. Clear phaseEnd so the local tick loop
        // stops; totalDurationMs is preserved so resume can recompute progress.
        val current = timerState.value
        applyTimerOptimistically(
            current.copy(
                status = "Paused",
                phaseEndEpochMs = 0L,
            ),
        )
        WearFocusService.start(getApplication())
        viewModelScope.launch {
            sendSafely("pause_timer") { sender.pauseTimer() }
        }
    }

    fun resumeTimer() {
        // Optimistic UI: show Running immediately and restart the countdown from "now".
        val current = timerState.value
        applyTimerOptimistically(
            current.copy(
                status = "Running",
                phaseEndEpochMs = optimisticPhaseEndMs(current),
            ),
        )
        WearFocusService.start(getApplication())
        viewModelScope.launch {
            sendSafely("resume_timer") { sender.resumeTimer() }
        }
    }

    fun stopTimer() {
        // Optimistic UI: show Idle immediately.
        applyTimerOptimistically(
            timerState.value.copy(
                status = "Idle",
                displayTime = timerState.value.displayTime,
                progress = 1f,
                phaseLabel = "Listo",
                phaseEndEpochMs = 0L,
                totalDurationMs = 0L,
            ),
        )
        WearFocusService.stop(getApplication())
        viewModelScope.launch {
            sendSafely("stop_timer") { sender.stopTimer() }
        }
    }

    fun skipPhase() {
        // Optimistic UI: show Running with next phase.
        // When transitioning from Work the watch does not carry sessionsBeforeLongBreak, so it
        // cannot reliably distinguish ShortBreak from LongBreak. We optimistically use "ShortBreak"
        // — it is occasionally wrong on the long-break boundary, but every UI check (Skip button
        // visibility, WaitingForNext labels, WearTheme color) works correctly with a recognised
        // phase string. The phone will sync the authoritative phase on its next push.
        val current = timerState.value
        val nextPhase = when (current.phase) {
            "Work" -> "ShortBreak" // optimistic; phone corrects to LongBreak if needed on next sync
            else -> "Work"
        }
        val nextLabel = if (nextPhase == "Work") "Focus" else "Descanso"
        val durationMs = defaultPhaseDurationMs(current.mode, nextPhase)
        applyTimerOptimistically(
            current.copy(
                status = "Running",
                phase = nextPhase,
                phaseLabel = nextLabel,
                progress = 0f,
                totalDurationMs = durationMs,
                phaseEndEpochMs = System.currentTimeMillis() + durationMs,
            ),
        )
        WearFocusService.start(getApplication())
        viewModelScope.launch {
            sendSafely("skip_phase") { sender.skipPhase() }
        }
    }

    fun completeTask(taskId: String) {
        // Optimistic UI: remove task from list immediately
        applyTasksOptimistically(
            tasks.value.filter { it.id != taskId },
        )
        viewModelScope.launch {
            sendSafely("complete_task") { sender.completeTask(taskId) }
        }
    }

    fun toggleTaskLink(taskId: String, taskTitle: String) {
        if (timerState.value.linkedTaskId == taskId) {
            // Optimistic UI: unlink immediately
            applyTimerOptimistically(
                timerState.value.copy(linkedTaskId = null, linkedTaskName = null),
            )
            viewModelScope.launch {
                sendSafely("unlink_task") { sender.unlinkTask() }
            }
        } else {
            // Optimistic UI: link immediately
            applyTimerOptimistically(
                timerState.value.copy(linkedTaskId = taskId, linkedTaskName = taskTitle),
            )
            viewModelScope.launch {
                sendSafely("link_task") { sender.linkTask(taskId) }
            }
        }
    }

    private suspend fun refreshNodeDiagnostics() {
        val nodes = runCatching {
            Wearable.getNodeClient(getApplication()).connectedNodes.await()
        }.getOrElse { error ->
            WearDataStore.recordSyncFailure("node_check: ${error.javaClass.simpleName}")
            emptyList()
        }

        WearDataStore.updateConnectedNodes(
            count = nodes.size,
            names = nodes.mapNotNull { node ->
                node.displayName?.takeIf { it.isNotBlank() } ?: node.id.takeIf { it.isNotBlank() }
            },
        )
    }
}
