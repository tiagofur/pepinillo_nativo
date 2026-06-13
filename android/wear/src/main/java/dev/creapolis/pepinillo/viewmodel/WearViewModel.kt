package dev.creapolis.pepinillo.viewmodel

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.google.android.gms.wearable.Wearable
import dev.creapolis.pepinillo.data.WearDataStore
import dev.creapolis.pepinillo.data.WearMessageSender
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

    fun startTimer(mode: String) {
        // Optimistic UI: show Running immediately
        WearDataStore.updateTimer(
            timerState.value.copy(
                mode = mode,
                status = "Running",
                phaseLabel = "Focus",
            ),
        )
        WearFocusService.start(getApplication())
        viewModelScope.launch {
            sendSafely("start_timer") { sender.startTimer(mode) }
        }
    }

    fun pauseTimer() {
        // Optimistic UI: show Paused immediately
        WearDataStore.updateTimer(
            timerState.value.copy(status = "Paused"),
        )
        WearFocusService.start(getApplication())
        viewModelScope.launch {
            sendSafely("pause_timer") { sender.pauseTimer() }
        }
    }

    fun resumeTimer() {
        // Optimistic UI: show Running immediately
        WearDataStore.updateTimer(
            timerState.value.copy(status = "Running"),
        )
        WearFocusService.start(getApplication())
        viewModelScope.launch {
            sendSafely("resume_timer") { sender.resumeTimer() }
        }
    }

    fun stopTimer() {
        // Optimistic UI: show Idle immediately
        WearDataStore.updateTimer(
            timerState.value.copy(
                status = "Idle",
                displayTime = timerState.value.displayTime,
                progress = 1f,
                phaseLabel = "Listo",
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
        WearDataStore.updateTimer(
            current.copy(
                status = "Running",
                phase = nextPhase,
                phaseLabel = nextLabel,
                progress = 1f,
            ),
        )
        WearFocusService.start(getApplication())
        viewModelScope.launch {
            sendSafely("skip_phase") { sender.skipPhase() }
        }
    }

    fun completeTask(taskId: String) {
        // Optimistic UI: remove task from list immediately
        WearDataStore.updateTasks(
            tasks.value.filter { it.id != taskId },
        )
        viewModelScope.launch {
            sendSafely("complete_task") { sender.completeTask(taskId) }
        }
    }

    fun toggleTaskLink(taskId: String, taskTitle: String) {
        if (timerState.value.linkedTaskId == taskId) {
            // Optimistic UI: unlink immediately
            WearDataStore.updateTimer(
                timerState.value.copy(linkedTaskId = null, linkedTaskName = null),
            )
            viewModelScope.launch {
                sendSafely("unlink_task") { sender.unlinkTask() }
            }
        } else {
            // Optimistic UI: link immediately
            WearDataStore.updateTimer(
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
