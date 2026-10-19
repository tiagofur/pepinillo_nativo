package dev.creapolis.pepinillo.viewmodel

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.google.android.gms.wearable.Wearable
import dev.creapolis.pepinillo.data.WearDataStore
import dev.creapolis.pepinillo.data.WearMessageSender
import dev.creapolis.pepinillo.data.WearSnapshotStore
import dev.creapolis.pepinillo.data.WearTimerDisplay
import dev.creapolis.pepinillo.data.WearTimerState
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.tasks.await

import dev.creapolis.pepinillo.service.WearFocusService
import dev.creapolis.pepinillo.R
import dev.creapolis.pepinillo.data.WearCommandWatchdog

class WearViewModel(application: Application) : AndroidViewModel(application) {
    private val sender = WearMessageSender(application)

    val timerState = WearDataStore.timerState
    val tasks = WearDataStore.tasks
    val stats = WearDataStore.stats
    val isPro = WearDataStore.isPro
    val pendingCommandCount = WearDataStore.pendingCommandCount
    val lastSyncAtMillis = WearDataStore.lastSyncAtMillis
    val diagnostics = WearDataStore.diagnostics

    private suspend fun sendSafely(tag: String, action: suspend () -> Boolean): Boolean =
        runCatching { action() }
            .onFailure { error ->
                WearDataStore.recordSyncFailure("$tag: ${error.javaClass.simpleName}")
            }
            .getOrDefault(false)

    /**
     * Sends a timer command under the E2 watchdog: GMS accepting the message does not
     * mean the phone processed it, so if no confirming timer DataItem
     * ([WearDataStore.remoteTimerRevisions] bump) arrives in time, the optimistic state
     * applied by the caller is rolled back to [previousState] and the command is
     * re-delivered once (or queued offline if undeliverable).
     */
    private fun launchTimerCommand(
        tag: String,
        optimisticState: WearTimerState,
        previousState: WearTimerState,
        action: suspend () -> Boolean,
    ) {
        viewModelScope.launch {
            WearCommandWatchdog.runCommand(
                remoteRevisions = WearDataStore.remoteTimerRevisions,
                timeoutMs = WearCommandWatchdog.DEFAULT_CONFIRMATION_TIMEOUT_MS,
                isStillOptimistic = { timerState.value == optimisticState },
                onRevert = {
                    // Restore the pre-command state in memory AND in the persisted
                    // snapshot so a cold restart doesn't resurrect the phantom session.
                    applyTimerOptimistically(previousState)
                },
                action = { sendSafely(tag) { action() } },
            )
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
        val previous = timerState.value
        val now = System.currentTimeMillis()
        val isCountUp = WearTimerDisplay.isCountUpMode(mode)
        val durationMs = previous.totalDurationMs.takeIf { it > 0 }
            ?: defaultPhaseDurationMs(mode, "Work")
        val optimistic = previous.copy(
            mode = mode,
            phase = "Work",
            status = "Running",
            phaseLabel = getApplication<Application>().getString(R.string.phase_focus),
            // #502: REMAINING for countdown (full ring at start), elapsed-0 for count-up.
            progress = if (isCountUp) 0f else 1f,
            displayTime = if (isCountUp) "00:00" else previous.displayTime,
            totalDurationMs = if (isCountUp) 0L else durationMs,
            phaseEndEpochMs = if (isCountUp) 0L else now + durationMs,
            phaseStartEpochMs = if (isCountUp) now else 0L,
            remainingDurationMs = 0L,
        )
        applyTimerOptimistically(optimistic)
        WearFocusService.start(getApplication())
        launchTimerCommand(
            tag = "start_timer",
            optimisticState = optimistic,
            previousState = previous,
        ) { sender.startTimer(mode) }
    }

    fun pauseTimer() {
        // Optimistic UI: freeze display time and stash remaining/elapsed for resume.
        val previous = timerState.value
        val now = System.currentTimeMillis()
        val isCountUp = WearTimerDisplay.isCountUpMode(previous.mode)
        val ticked = WearTimerDisplay.tick(previous, now)
        val remainingMs = if (isCountUp) {
            if (previous.phaseStartEpochMs > 0L) now - previous.phaseStartEpochMs else previous.remainingDurationMs
        } else {
            when {
                previous.phaseEndEpochMs > 0L -> (previous.phaseEndEpochMs - now).coerceAtLeast(0L)
                previous.remainingDurationMs > 0L -> previous.remainingDurationMs
                else -> previous.totalDurationMs
            }
        }
        val progress = if (isCountUp) {
            ticked.progress
        } else if (previous.totalDurationMs > 0L) {
            // #502: REMAINING polarity — pause freezes the remaining fraction directly.
            (remainingMs.toFloat() / previous.totalDurationMs).coerceIn(0f, 1f)
        } else {
            previous.progress
        }
        val optimistic = previous.copy(
            status = "Paused",
            displayTime = ticked.displayTime,
            progress = progress,
            remainingDurationMs = remainingMs,
            phaseEndEpochMs = 0L,
            phaseStartEpochMs = 0L,
        )
        applyTimerOptimistically(optimistic)
        WearFocusService.start(getApplication())
        launchTimerCommand(
            tag = "pause_timer",
            optimisticState = optimistic,
            previousState = previous,
        ) { sender.pauseTimer() }
    }

    fun resumeTimer() {
        // Optimistic UI: resume from preserved remaining/elapsed, not the full phase duration.
        val previous = timerState.value
        val now = System.currentTimeMillis()
        val isCountUp = WearTimerDisplay.isCountUpMode(previous.mode)
        val remainingMs = previous.remainingDurationMs.takeIf { it > 0L }
            ?: previous.totalDurationMs.takeIf { it > 0L }
            ?: defaultPhaseDurationMs(previous.mode, previous.phase)
        val optimistic =
            if (isCountUp) {
                previous.copy(
                    status = "Running",
                    phaseStartEpochMs = now - remainingMs,
                    phaseEndEpochMs = 0L,
                    remainingDurationMs = 0L,
                )
            } else {
                previous.copy(
                    status = "Running",
                    phaseEndEpochMs = now + remainingMs,
                    phaseStartEpochMs = 0L,
                    remainingDurationMs = 0L,
                )
            }
        applyTimerOptimistically(optimistic)
        WearFocusService.start(getApplication())
        launchTimerCommand(
            tag = "resume_timer",
            optimisticState = optimistic,
            previousState = previous,
        ) { sender.resumeTimer() }
    }

    fun stopTimer() {
        // Optimistic UI: show Idle immediately.
        applyTimerOptimistically(
            timerState.value.copy(
                status = "Idle",
                displayTime = timerState.value.displayTime,
                progress = 1f,
                phaseLabel = getApplication<Application>().getString(R.string.state_ready),
                phaseEndEpochMs = 0L,
                phaseStartEpochMs = 0L,
                remainingDurationMs = 0L,
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
            "Work" -> {
                val cycleComplete = (current.completedSessions + 1) % current.sessionsBeforeLongBreak == 0
                if (cycleComplete) "LongBreak" else "ShortBreak"
            }
            else -> "Work"
        }
        val nextLabel = if (nextPhase == "Work") {
            getApplication<Application>().getString(R.string.phase_focus)
        } else {
            getApplication<Application>().getString(R.string.phase_break)
        }
        val durationMs = defaultPhaseDurationMs(current.mode, nextPhase)
        val now = System.currentTimeMillis()
        val optimistic = current.copy(
            status = "Running",
            phase = nextPhase,
            phaseLabel = nextLabel,
            // #502: REMAINING — full ring at the start of the next countdown phase.
            progress = 1f,
            totalDurationMs = durationMs,
            phaseEndEpochMs = now + durationMs,
            phaseStartEpochMs = 0L,
            remainingDurationMs = 0L,
        )
        applyTimerOptimistically(optimistic)
        WearFocusService.start(getApplication())
        launchTimerCommand(
            tag = "skip_phase",
            optimisticState = optimistic,
            previousState = current,
        ) { sender.skipPhase() }
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
