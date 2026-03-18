package dev.creapolis.pepinillo.service

import android.content.ComponentName
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.util.Log
import androidx.wear.tiles.TileService
import com.google.android.gms.wearable.MessageEvent
import androidx.wear.watchface.complications.datasource.ComplicationDataSourceUpdateRequester
import com.google.android.gms.wearable.DataEvent
import com.google.android.gms.wearable.DataEventBuffer
import com.google.android.gms.wearable.DataMapItem
import com.google.android.gms.wearable.WearableListenerService
import dev.creapolis.pepinillo.complication.FocusComplicationDataSource
import dev.creapolis.pepinillo.data.WearDataFetcher
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
import java.util.Date

private const val TAG = "WearSyncListener"

class WearSyncListenerService : WearableListenerService() {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private val processor = WearSyncProcessor(
        object : WearSyncSink {
            override fun updateTimer(state: WearTimerState) {
                WearDataStore.updateTimer(state)
            }

            override fun persistTimer(state: WearTimerState) {
                WearSnapshotStore.persistTimerState(this@WearSyncListenerService, state)
            }

            override fun updateTasksFromJson(tasksJson: String): List<dev.creapolis.pepinillo.data.WearTask> {
                WearDataStore.updateTasksFromJson(tasksJson)
                return WearDataStore.tasks.value
            }

            override fun persistTasks(tasks: List<dev.creapolis.pepinillo.data.WearTask>) {
                WearSnapshotStore.persistTasks(this@WearSyncListenerService, tasks)
            }

            override fun updateStats(state: WearStatsState) {
                WearDataStore.updateStats(state)
            }

            override fun persistStats(state: WearStatsState) {
                WearSnapshotStore.persistStats(this@WearSyncListenerService, state)
            }

            override fun markSyncedNow() {
                this@WearSyncListenerService.markSyncedNow()
            }

            override fun refreshWearSurfaces() {
                this@WearSyncListenerService.refreshWearSurfaces()
            }

            override fun recordSyncEvent() {
                WearDataStore.recordSyncEvent()
            }
        },
    )

    private fun refreshWearSurfaces() {
        try {
            TileService.getUpdater(this).requestUpdate(FocusTileService::class.java)
        } catch (e: SecurityException) {
            Log.w(TAG, "Cannot update tile (targetSdk>34 restriction)", e)
        }
        ComplicationDataSourceUpdateRequester
            .create(
                context = this,
                complicationDataSourceComponent = ComponentName(this, FocusComplicationDataSource::class.java),
            )
            .requestUpdateAll()
    }

    private fun markSyncedNow() {
        val now = Date().time
        WearDataStore.updateLastSyncAtMillis(now)
        WearSnapshotStore.persistLastSyncAtMillis(this, now)
    }

    override fun onMessageReceived(messageEvent: MessageEvent) {
        when (messageEvent.path) {
            "/pepinillo/event/phase_complete" -> {
                Log.d(TAG, "Phase complete event received — vibrating")
                vibrateWatch()
            }
        }
    }

    private fun vibrateWatch() {
        val vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val manager = getSystemService(VIBRATOR_MANAGER_SERVICE) as VibratorManager
            manager.defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            getSystemService(VIBRATOR_SERVICE) as Vibrator
        }
        if (!vibrator.hasVibrator()) return
        // Double pulse: buzz - pause - buzz (same as phone)
        val effect = VibrationEffect.createWaveform(
            longArrayOf(0, 300, 150, 300),
            -1,
        )
        vibrator.vibrate(effect)
    }

    override fun onDataChanged(dataEvents: DataEventBuffer) {
        dataEvents.forEach { event ->
            if (event.type != DataEvent.TYPE_CHANGED) return@forEach
            val item = event.dataItem
            val path = item.uri.path ?: return@forEach
            val dataMap = DataMapItem.fromDataItem(item).dataMap

            when (path) {
                WearDataPaths.PATH_TIMER -> {
                    val linkedId = dataMap.getString("linkedTaskId", "")
                    val timerState = WearTimerState(
                        mode = dataMap.getString("mode", "Pomodoro"),
                        phase = dataMap.getString("phase", "Work"),
                        status = dataMap.getString("status", "Idle"),
                        displayTime = dataMap.getString("displayTime", "00:00"),
                        phaseLabel = dataMap.getString("phaseLabel", "Focus"),
                        progress = dataMap.getFloat("progress", 0f),
                        isConnected = true,
                        linkedTaskId = linkedId.ifEmpty { null },
                        linkedTaskName = dataMap.getString("linkedTaskName", "").ifEmpty { null },
                    )
                    processor.onTimerData(timerState)
                }

                WearDataPaths.PATH_TASKS -> {
                    val tasksJson = dataMap.getString("tasksJson", "[]")
                    processor.onTasksData(tasksJson)
                }

                WearDataPaths.PATH_STATS -> {
                    val statsState = WearStatsState(
                        totalMinutes = dataMap.getInt("totalMinutes", 0),
                        sessions = dataMap.getInt("sessions", 0),
                        streak = dataMap.getInt("streak", 0),
                        completedTasks = dataMap.getInt("completedTasksToday", 0),
                    )
                    processor.onStatsData(statsState)
                }
            }
        }
    }

    override fun onPeerConnected(peer: com.google.android.gms.wearable.Node) {
        super.onPeerConnected(peer)
        scope.launch {
            runCatching { WearMessageSender(this@WearSyncListenerService).flushPendingCommands() }
                .onFailure { e ->
                    Log.w(TAG, "Failed to flush pending commands", e)
                    WearDataStore.recordSyncFailure("flush_pending: ${e.javaClass.simpleName}")
                }

            WearDataFetcher.fetchAndApplyAll(this@WearSyncListenerService)
        }
    }

    override fun onPeerDisconnected(peer: com.google.android.gms.wearable.Node) {
        super.onPeerDisconnected(peer)
        processor.onPeerDisconnected(WearDataStore.timerState.value)
    }

    override fun onDestroy() {
        scope.cancel()
        super.onDestroy()
    }
}
