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

class WearViewModel(application: Application) : AndroidViewModel(application) {
    private val sender = WearMessageSender(application)

    val timerState = WearDataStore.timerState
    val tasks = WearDataStore.tasks
    val stats = WearDataStore.stats
    val pendingCommandCount = WearDataStore.pendingCommandCount
    val lastSyncAtMillis = WearDataStore.lastSyncAtMillis
    val diagnostics = WearDataStore.diagnostics

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
        viewModelScope.launch { sender.startTimer(mode) }
    }

    fun pauseTimer() {
        // Optimistic UI: show Paused immediately
        WearDataStore.updateTimer(
            timerState.value.copy(status = "Paused"),
        )
        viewModelScope.launch { sender.pauseTimer() }
    }

    fun resumeTimer() {
        // Optimistic UI: show Running immediately
        WearDataStore.updateTimer(
            timerState.value.copy(status = "Running"),
        )
        viewModelScope.launch { sender.resumeTimer() }
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
        viewModelScope.launch { sender.stopTimer() }
    }

    fun skipPhase() {
        // Optimistic UI: show Running with next phase
        val current = timerState.value
        val nextPhase = if (current.phase == "Work") "ShortBreak" else "Work"
        val nextLabel = if (nextPhase == "Work") "Focus" else "Descanso"
        WearDataStore.updateTimer(
            current.copy(
                status = "Running",
                phase = nextPhase,
                phaseLabel = nextLabel,
                progress = 1f,
            ),
        )
        viewModelScope.launch { sender.skipPhase() }
    }

    fun completeTask(taskId: String) {
        // Optimistic UI: remove task from list immediately
        WearDataStore.updateTasks(
            tasks.value.filter { it.id != taskId },
        )
        viewModelScope.launch { sender.completeTask(taskId) }
    }

    fun toggleTaskLink(taskId: String, taskTitle: String) {
        if (timerState.value.linkedTaskId == taskId) {
            // Optimistic UI: unlink immediately
            WearDataStore.updateTimer(
                timerState.value.copy(linkedTaskId = null, linkedTaskName = null),
            )
            viewModelScope.launch { sender.unlinkTask() }
        } else {
            // Optimistic UI: link immediately
            WearDataStore.updateTimer(
                timerState.value.copy(linkedTaskId = taskId, linkedTaskName = taskTitle),
            )
            viewModelScope.launch { sender.linkTask(taskId) }
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
