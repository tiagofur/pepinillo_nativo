package dev.creapolis.pepinillo.service

import android.content.ComponentName
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.util.Log
import androidx.wear.tiles.TileService
import com.google.android.gms.wearable.CapabilityInfo
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
import dev.creapolis.pepinillo.data.WearThemeColors
import dev.creapolis.pepinillo.data.WearTimerState
import dev.creapolis.pepinillo.tile.FocusTileService
import dev.creapolis.pepinillo.tile.TasksTileService
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import java.util.Date

private const val TAG = "WearSyncListener"

class WearSyncListenerService : WearableListenerService() {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private val debouncedRefresh = DebouncedRefreshSurfaces(scope) { refreshWearSurfaces() }
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
                this@WearSyncListenerService.debouncedRefresh.submit()
            }

            override fun recordSyncEvent() {
                WearDataStore.recordSyncEvent()
            }
        },
    )

    private fun refreshWearSurfaces() {
        try {
            TileService.getUpdater(this).requestUpdate(FocusTileService::class.java)
            TileService.getUpdater(this).requestUpdate(TasksTileService::class.java)
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
                    val mode = dataMap.getString("mode", "Pomodoro")
                    val status = dataMap.getString("status", "Idle")
                    val elapsedMillis = dataMap.getLong("elapsedMillis")
                    val totalMillis = dataMap.getLong("totalMillis")
                    val timestamp = dataMap.getLong("timestamp")
                    val isCountUp = mode == "Flow" || mode == "Chrono"
                    // Epoch anchors so the watch can tick locally between phone syncs.
                    val phaseStartEpochMs = if (status == "Running") {
                        timestamp - elapsedMillis
                    } else {
                        0L
                    }
                    val phaseEndEpochMs = if (status == "Running" && totalMillis > 0) {
                        timestamp + (totalMillis - elapsedMillis)
                    } else {
                        0L
                    }
                    val remainingDurationMs = if (status == "Paused") {
                        if (isCountUp) elapsedMillis else (totalMillis - elapsedMillis).coerceAtLeast(0L)
                    } else {
                        0L
                    }
                    val timerState = WearTimerState(
                        mode = mode,
                        phase = dataMap.getString("phase", "Work"),
                        status = status,
                        displayTime = dataMap.getString("displayTime", "00:00"),
                        phaseLabel = dataMap.getString("phaseLabel", "Focus"),
                        progress = dataMap.getFloat("progress", 0f),
                        isConnected = true,
                        linkedTaskId = linkedId.ifEmpty { null },
                        linkedTaskName = dataMap.getString("linkedTaskName", "").ifEmpty { null },
                        completedSessions = dataMap.getInt("completedSessions", 0),
                        phaseEndEpochMs = phaseEndEpochMs,
                        phaseStartEpochMs = phaseStartEpochMs,
                        remainingDurationMs = remainingDurationMs,
                        totalDurationMs = totalMillis,
                    )
                    processor.onTimerData(timerState)
                    // E2: this DataItem is the phone's authoritative confirmation of a
                    // timer command — bump the revision the command watchdog waits on.
                    WearDataStore.recordRemoteTimerRevision()

                    // E3: keep the foreground service (notification + day-change receiver
                    // + day-change backstop) alive for every status WearFocusService treats
                    // as foreground-worthy — WaitingForNext too, not just Running/Paused.
                    if (WearFocusService.isForegroundServiceStatus(status)) {
                        WearFocusService.start(this@WearSyncListenerService)
                    } else {
                        WearFocusService.stop(this@WearSyncListenerService)
                    }
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

                WearDataPaths.PATH_USER -> {
                    val isPro = dataMap.getBoolean("isPro", false)
                    val sessions = dataMap.getInt("sessionsBeforeLongBreak", 4)
                    Log.d(TAG, "User DataItem changed, isPro=$isPro, sessions=$sessions")
                    
                    val currentTimer = WearDataStore.timerState.value
                    if (currentTimer.sessionsBeforeLongBreak != sessions) {
                        val updated = currentTimer.copy(sessionsBeforeLongBreak = sessions)
                        WearDataStore.updateTimer(updated)
                        WearSnapshotStore.persistTimerState(this@WearSyncListenerService, updated)
                    }

                    WearDataStore.updateIsPro(isPro)
                    WearSnapshotStore.persistIsPro(this@WearSyncListenerService, isPro)
                }

                "/pepinillo/theme" -> {
                    val themeId = dataMap.getString("themeId") ?: "classic"
                    val colors = WearThemeColors(
                        themeId = themeId,
                        pomodoroColor = dataMap.getLong("pomodoroColor"),
                        flowtimeColor = dataMap.getLong("flowtimeColor"),
                        timeBlockColor = dataMap.getLong("timeBlockColor"),
                        stopwatchColor = dataMap.getLong("stopwatchColor"),
                        streakColor = dataMap.getLong("streakColor"),
                    )
                    WearDataStore.updateThemeColors(colors)
                    WearSnapshotStore.persistThemeColors(this@WearSyncListenerService, colors)
                }
            }
        }
    }

    override fun onPeerConnected(peer: com.google.android.gms.wearable.Node) {
        @Suppress("DEPRECATION")
        super.onPeerConnected(peer)
        Log.w(TAG, "onPeerConnected is deprecated since GMS 17.0.0; onCapabilityChanged is preferred")
        flushAndFetch()
    }

    override fun onPeerDisconnected(peer: com.google.android.gms.wearable.Node) {
        super.onPeerDisconnected(peer)
        processor.onPeerDisconnected(WearDataStore.timerState.value)
    }

    override fun onCapabilityChanged(capabilityInfo: CapabilityInfo) {
        super.onCapabilityChanged(capabilityInfo)
        // Modern reconnect signal (replaces the deprecated onPeerConnected path).
        // Fires when a node advertising the `pepinillo_phone` capability becomes reachable.
        if (capabilityInfo.nodes.isNotEmpty()) {
            Log.d(TAG, "onCapabilityChanged: ${capabilityInfo.nodes.size} phone node(s) reachable")
            flushAndFetch()
        }
    }

    private fun flushAndFetch() {
        scope.launch {
            runCatching { WearMessageSender(this@WearSyncListenerService).flushPendingCommands() }
                .onFailure { e ->
                    Log.w(TAG, "Failed to flush pending commands", e)
                    WearDataStore.recordSyncFailure("flush_pending: ${e.javaClass.simpleName}")
                }

            WearDataFetcher.fetchAndApplyAll(this@WearSyncListenerService)
        }
    }

    override fun onDestroy() {
        scope.cancel()
        super.onDestroy()
    }
}
