package dev.creapolis.pepinillo.data

import android.content.Context
import android.util.Log
import com.google.android.gms.wearable.DataMapItem
import com.google.android.gms.wearable.Wearable
import kotlinx.coroutines.tasks.await

private const val TAG = "WearDataFetcher"

object WearDataFetcher {

    suspend fun fetchAndApplyAll(context: Context) {
        Log.d(TAG, "Fetching all DataClient items")
        runCatching {
            val buffer = Wearable.getDataClient(context).dataItems.await()
            try {
                Log.d(TAG, "DataClient items count: ${buffer.count}")
                // P2(h): DataItems are a replicated store — they can be STALE snapshots of
                // the last connection. Only a live node query may mark the phone connected,
                // otherwise the UI claims "connected" from cached data while offline.
                val liveConnected = runCatching {
                    Wearable.getNodeClient(context).connectedNodes.await().isNotEmpty()
                }.getOrDefault(false)
                buffer.forEach { item ->
                    val path = item.uri.path ?: return@forEach
                    Log.d(TAG, "DataItem path=$path uri=${item.uri}")
                    val map = DataMapItem.fromDataItem(item).dataMap
                    when (path) {
                        WearDataPaths.PATH_TIMER -> {
                            val lid = map.getString("linkedTaskId", "")
                            val mode = map.getString("mode", "Pomodoro")
                            val status = map.getString("status", "Idle")
                            val elapsedMillis = map.getLong("elapsedMillis")
                            val totalMillis = map.getLong("totalMillis")
                            val timestamp = map.getLong("timestamp")
                            val isCountUp = mode == "Flow" || mode == "Chrono"
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
                                phase = map.getString("phase", "Work"),
                                status = status,
                                displayTime = map.getString("displayTime", "00:00"),
                                phaseLabel = map.getString("phaseLabel", "Focus"),
                                progress = map.getFloat("progress", 0f),
                                isConnected = liveConnected,
                                linkedTaskId = lid.ifEmpty { null },
                                linkedTaskName = map.getString("linkedTaskName", "").ifEmpty { null },
                                completedSessions = map.getInt("completedSessions", 0),
                                phaseEndEpochMs = phaseEndEpochMs,
                                phaseStartEpochMs = phaseStartEpochMs,
                                remainingDurationMs = remainingDurationMs,
                                totalDurationMs = totalMillis,
                            )
                            WearDataStore.updateTimer(timerState)
                            WearSnapshotStore.persistTimerState(context, timerState)
                            // E2: fetched timer DataItem counts as an authoritative phone
                            // confirmation for the command watchdog.
                            WearDataStore.recordRemoteTimerRevision()
                        }

                        WearDataPaths.PATH_TASKS -> {
                            val tasksJson = map.getString("tasksJson", "[]")
                            Log.d(TAG, "Tasks DataItem found, json length=${tasksJson.length}")
                            WearDataStore.updateTasksFromJson(tasksJson)
                            val tasks = WearDataStore.tasks.value
                            Log.d(TAG, "Parsed ${tasks.size} tasks from DataClient")
                            WearSnapshotStore.persistTasks(context, tasks)
                        }

                        WearDataPaths.PATH_STATS -> {
                            val statsState = WearStatsState(
                                totalMinutes = map.getInt("totalMinutes", 0),
                                sessions = map.getInt("sessions", 0),
                                streak = map.getInt("streak", 0),
                                completedTasks = map.getInt("completedTasksToday", 0),
                            )
                            WearDataStore.updateStats(statsState)
                            WearSnapshotStore.persistStats(context, statsState)
                        }

                        WearDataPaths.PATH_USER -> {
                            val isPro = map.getBoolean("isPro", false)
                            Log.d(TAG, "User DataItem found, isPro=$isPro")
                            WearDataStore.updateIsPro(isPro)
                        }

                        "/pepinillo/theme" -> {
                            val themeId = map.getString("themeId") ?: "classic"
                            val colors = WearThemeColors(
                                themeId = themeId,
                                pomodoroColor = map.getLong("pomodoroColor"),
                                flowtimeColor = map.getLong("flowtimeColor"),
                                timeBlockColor = map.getLong("timeBlockColor"),
                                stopwatchColor = map.getLong("stopwatchColor"),
                                streakColor = map.getLong("streakColor"),
                            )
                            WearDataStore.updateThemeColors(colors)
                        }
                    }
                }
                val syncTime = java.util.Date().time
                WearDataStore.updateLastSyncAtMillis(syncTime)
                WearSnapshotStore.persistLastSyncAtMillis(context, syncTime)
                WearDataStore.recordSyncEvent()
                Log.d(TAG, "DataClient items applied successfully")
            } finally {
                buffer.release()
            }
        }.onFailure { e ->
            Log.w(TAG, "Failed to fetch DataClient items", e)
            WearDataStore.recordSyncFailure("data_fetch: ${e.javaClass.simpleName}")
        }
    }

    suspend fun requestSyncFromPhone(context: Context) {
        // Proactively drain any queued commands. onCapabilityChanged may not have fired
        // (e.g. capability info already cached, GMS quiescent), and the user opening the
        // app is a strong signal that we should attempt delivery now.
        runCatching {
            WearMessageSender(context).flushPendingCommands()
        }.onFailure { e ->
            Log.w(TAG, "Proactive flush in requestSyncFromPhone failed", e)
        }

        runCatching {
            val nodes = Wearable.getNodeClient(context).connectedNodes.await()
            nodes.forEach { node ->
                Wearable.getMessageClient(context)
                    .sendMessage(node.id, WearDataPaths.CMD_REQUEST_SYNC, byteArrayOf())
                    .await()
            }
            Log.d(TAG, "Requested sync from phone (${nodes.size} nodes)")
        }.onFailure { e ->
            Log.w(TAG, "Failed to request sync from phone", e)
        }
    }
}
