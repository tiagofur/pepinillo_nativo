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
                buffer.forEach { item ->
                    val path = item.uri.path ?: return@forEach
                    Log.d(TAG, "DataItem path=$path uri=${item.uri}")
                    val map = DataMapItem.fromDataItem(item).dataMap
                    when (path) {
                        WearDataPaths.PATH_TIMER -> {
                            val lid = map.getString("linkedTaskId", "")
                            val timerState = WearTimerState(
                                mode = map.getString("mode", "Pomodoro"),
                                phase = map.getString("phase", "Work"),
                                status = map.getString("status", "Idle"),
                                displayTime = map.getString("displayTime", "00:00"),
                                phaseLabel = map.getString("phaseLabel", "Focus"),
                                progress = map.getFloat("progress", 0f),
                                isConnected = true,
                                linkedTaskId = lid.ifEmpty { null },
                                linkedTaskName = map.getString("linkedTaskName", "").ifEmpty { null },
                            )
                            WearDataStore.updateTimer(timerState)
                            WearSnapshotStore.persistTimerState(context, timerState)
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
