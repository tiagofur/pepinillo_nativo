package dev.creapolis.pepinillo.service

import android.content.ComponentName
import android.util.Log
import androidx.wear.tiles.TileService
import androidx.wear.watchface.complications.datasource.ComplicationDataSourceUpdateRequester
import com.google.android.gms.wearable.DataEvent
import com.google.android.gms.wearable.DataEventBuffer
import com.google.android.gms.wearable.DataMapItem
import com.google.android.gms.wearable.Wearable
import com.google.android.gms.wearable.WearableListenerService
import dev.creapolis.pepinillo.complication.FocusComplicationDataSource
import dev.creapolis.pepinillo.data.WearDataPaths
import dev.creapolis.pepinillo.data.WearDataStore
import dev.creapolis.pepinillo.data.WearMessageSender
import dev.creapolis.pepinillo.data.WearSnapshotStore
import dev.creapolis.pepinillo.data.WearStatsState
import dev.creapolis.pepinillo.data.WearTimerState
import dev.creapolis.pepinillo.tile.FocusTileService
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import kotlinx.coroutines.tasks.await
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

private const val TAG = "WearSyncListener"

class WearSyncListenerService : WearableListenerService() {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private val timeFormatter = SimpleDateFormat("HH:mm", Locale.getDefault())

    private fun refreshWearSurfaces() {
        TileService.getUpdater(this).requestUpdate(FocusTileService::class.java)
        ComplicationDataSourceUpdateRequester
            .create(
                context = this,
                complicationDataSourceComponent = ComponentName(this, FocusComplicationDataSource::class.java),
            )
            .requestUpdateAll()
    }

    private fun markSyncedNow() {
        WearDataStore.updateLastSyncLabel("Sync ${timeFormatter.format(Date())}")
    }

    override fun onDataChanged(dataEvents: DataEventBuffer) {
        dataEvents.forEach { event ->
            if (event.type != DataEvent.TYPE_CHANGED) return@forEach
            val item = event.dataItem
            val path = item.uri.path ?: return@forEach
            val dataMap = DataMapItem.fromDataItem(item).dataMap

            when (path) {
                WearDataPaths.PATH_TIMER -> {
                    val timerState = WearTimerState(
                        mode = dataMap.getString("mode", "Pomodoro"),
                        phase = dataMap.getString("phase", "Work"),
                        status = dataMap.getString("status", "Idle"),
                        displayTime = dataMap.getString("displayTime", "00:00"),
                        phaseLabel = dataMap.getString("phaseLabel", "Focus"),
                        progress = dataMap.getFloat("progress", 0f),
                        isConnected = true,
                    )
                    WearDataStore.updateTimer(timerState)
                    WearSnapshotStore.persistTimerState(this, timerState)
                    markSyncedNow()
                    refreshWearSurfaces()
                }

                WearDataPaths.PATH_TASKS -> {
                    val tasksJson = dataMap.getString("tasksJson", "[]")
                    WearDataStore.updateTasksFromJson(tasksJson)
                    WearSnapshotStore.persistTasks(this, WearDataStore.tasks.value)
                    markSyncedNow()
                }

                WearDataPaths.PATH_STATS -> {
                    val statsState = WearStatsState(
                        totalMinutes = dataMap.getInt("totalMinutes", 0),
                        sessions = dataMap.getInt("sessions", 0),
                        streak = dataMap.getInt("streak", 0),
                        completedTasks = dataMap.getInt("completedTasksToday", 0),
                    )
                    WearDataStore.updateStats(statsState)
                    WearSnapshotStore.persistStats(this, statsState)
                    markSyncedNow()
                }
            }
        }
    }

    override fun onPeerConnected(peer: com.google.android.gms.wearable.Node) {
        super.onPeerConnected(peer)
        scope.launch {
            runCatching { WearMessageSender(this@WearSyncListenerService).flushPendingCommands() }
                .onFailure { e -> Log.w(TAG, "Failed to flush pending commands", e) }

            runCatching {
                val buffer = Wearable.getDataClient(this@WearSyncListenerService).dataItems.await()
                try {
                    buffer.forEach { item ->
                        val path = item.uri.path ?: return@forEach
                        val map = DataMapItem.fromDataItem(item).dataMap
                        when (path) {
                            WearDataPaths.PATH_TIMER -> {
                                val timerState = WearTimerState(
                                    mode = map.getString("mode", "Pomodoro"),
                                    phase = map.getString("phase", "Work"),
                                    status = map.getString("status", "Idle"),
                                    displayTime = map.getString("displayTime", "00:00"),
                                    phaseLabel = map.getString("phaseLabel", "Focus"),
                                    progress = map.getFloat("progress", 0f),
                                    isConnected = true,
                                )
                                WearDataStore.updateTimer(timerState)
                                WearSnapshotStore.persistTimerState(this@WearSyncListenerService, timerState)
                                markSyncedNow()
                                refreshWearSurfaces()
                            }

                            WearDataPaths.PATH_TASKS -> {
                                val tasksJson = map.getString("tasksJson", "[]")
                                WearDataStore.updateTasksFromJson(tasksJson)
                                WearSnapshotStore.persistTasks(this@WearSyncListenerService, WearDataStore.tasks.value)
                                markSyncedNow()
                            }

                            WearDataPaths.PATH_STATS -> {
                                val statsState = WearStatsState(
                                    totalMinutes = map.getInt("totalMinutes", 0),
                                    sessions = map.getInt("sessions", 0),
                                    streak = map.getInt("streak", 0),
                                    completedTasks = map.getInt("completedTasksToday", 0),
                                )
                                WearDataStore.updateStats(statsState)
                                WearSnapshotStore.persistStats(this@WearSyncListenerService, statsState)
                                markSyncedNow()
                            }
                        }
                    }
                } finally {
                    buffer.release()
                }
            }.onFailure { e -> Log.w(TAG, "Failed to fetch initial wearable snapshot", e) }
        }
    }

    override fun onPeerDisconnected(peer: com.google.android.gms.wearable.Node) {
        super.onPeerDisconnected(peer)
        val timerState = WearDataStore.timerState.value.copy(isConnected = false, status = "Disconnected")
        WearDataStore.updateTimer(timerState)
        WearSnapshotStore.persistTimerState(this, timerState)
        refreshWearSurfaces()
    }

    override fun onDestroy() {
        scope.cancel()
        super.onDestroy()
    }
}
