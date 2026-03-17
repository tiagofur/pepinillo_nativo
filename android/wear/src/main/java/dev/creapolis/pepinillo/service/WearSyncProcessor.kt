package dev.creapolis.pepinillo.service

import dev.creapolis.pepinillo.data.WearStatsState
import dev.creapolis.pepinillo.data.WearTask
import dev.creapolis.pepinillo.data.WearTimerState

internal interface WearSyncSink {
    fun updateTimer(state: WearTimerState)
    fun persistTimer(state: WearTimerState)
    fun updateTasksFromJson(tasksJson: String): List<WearTask>
    fun persistTasks(tasks: List<WearTask>)
    fun updateStats(state: WearStatsState)
    fun persistStats(state: WearStatsState)
    fun markSyncedNow()
    fun refreshWearSurfaces()
}

internal class WearSyncProcessor(
    private val sink: WearSyncSink,
) {
    fun onTimerData(state: WearTimerState) {
        sink.updateTimer(state)
        sink.persistTimer(state)
        sink.markSyncedNow()
        sink.refreshWearSurfaces()
    }

    fun onTasksData(tasksJson: String) {
        val tasks = sink.updateTasksFromJson(tasksJson)
        sink.persistTasks(tasks)
        sink.markSyncedNow()
    }

    fun onStatsData(state: WearStatsState) {
        sink.updateStats(state)
        sink.persistStats(state)
        sink.markSyncedNow()
    }

    fun onPeerDisconnected(currentTimer: WearTimerState) {
        val disconnected = currentTimer.copy(isConnected = false, status = "Disconnected")
        sink.updateTimer(disconnected)
        sink.persistTimer(disconnected)
        sink.refreshWearSurfaces()
    }
}
