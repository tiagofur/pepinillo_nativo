package dev.creapolis.pepinillo.data.sync

import android.util.Log
import dev.creapolis.pepinillo.core.auth.AuthStore
import dev.creapolis.pepinillo.core.network.NetworkResult
import dev.creapolis.pepinillo.core.network.PepinilloApiClient
import dev.creapolis.pepinillo.core.network.TaskDto
import dev.creapolis.pepinillo.core.network.TaskSyncRequest
import dev.creapolis.pepinillo.data.local.dao.FocusSessionDao
import dev.creapolis.pepinillo.data.local.dao.TaskDao
import dev.creapolis.pepinillo.data.local.entity.TaskEntity
import dev.creapolis.pepinillo.core.network.PomodoroSessionDto
import javax.inject.Inject
import javax.inject.Singleton

private const val TAG = "SyncEngine"

sealed class SyncResult {
    data object Success : SyncResult()
    data object NotAuthenticated : SyncResult()
    data class Error(val exception: Throwable) : SyncResult()
}

@Singleton
class SyncEngine @Inject constructor(
    private val taskDao: TaskDao,
    private val sessionDao: FocusSessionDao,
    private val apiClient: PepinilloApiClient,
    private val authStore: AuthStore,
) {
    suspend fun syncAll(): SyncResult {
        if (authStore.getAccessToken() == null) return SyncResult.NotAuthenticated
        return try {
            syncTasks()
            syncSessions()
            SyncResult.Success
        } catch (e: Exception) {
            Log.e(TAG, "Sync failed", e)
            SyncResult.Error(e)
        }
    }

    private suspend fun syncTasks() {
        val dirtyTasks = taskDao.getDirtyTasks()
        if (dirtyTasks.isEmpty()) return

        val deletedSyncIds = dirtyTasks
            .filter { it.isDeleted }
            .map { it.id }

        val tasksToSync = dirtyTasks
            .filter { !it.isDeleted }
            .map { it.toDto() }

        val request = TaskSyncRequest(
            tasks = tasksToSync,
            deletedSyncIds = deletedSyncIds,
        )

        when (val result = apiClient.syncTasks(request)) {
            is NetworkResult.Success -> {
                val response = result.data
                val now = System.currentTimeMillis()

                // Mark pushed tasks as synced
                for (task in dirtyTasks) {
                    if (task.isDeleted) continue
                    val serverTask = response.tasks.find { it.syncId == task.id }
                    val serverId = serverTask?.id ?: (task.serverId ?: 0)
                    taskDao.markSynced(task.id, now, serverId)
                }

                // Merge server tasks into local DB (last-write-wins)
                for (serverTask in response.tasks) {
                    val localBySyncId = serverTask.syncId.takeIf { it.isNotEmpty() }
                        ?.let { taskDao.getTaskById(it) }
                    val local = localBySyncId
                        ?: taskDao.getTaskByServerId(serverTask.id)
                    if (local == null) {
                        // New task from server
                        taskDao.insertTask(serverTask.toEntity())
                    } else if (!local.isDirty && serverTask.updatedAt > local.updatedAt) {
                        // Server version is newer and local isn't dirty
                        taskDao.updateTask(serverTask.toEntity().copy(
                            id = local.id,
                            isDirty = false,
                            syncedAt = now,
                            serverId = serverTask.id,
                        ))
                    }
                }

                // Purge soft-deleted tasks that were successfully synced
                taskDao.purgeDeletedSynced()

                Log.d(TAG, "Tasks synced: ${response.tasks.size} received")
            }
            is NetworkResult.Error -> Log.e(TAG, "Task sync error: ${result.code} ${result.message}")
            is NetworkResult.NetworkError -> throw result.exception
        }
    }

    private suspend fun syncSessions() {
        val dirtySessions = sessionDao.getDirtySessions()
        if (dirtySessions.isEmpty()) return

        val now = System.currentTimeMillis()
        for (session in dirtySessions) {
            val dto = PomodoroSessionDto(
                id = session.id,
                startedAt = session.startTime,
                endedAt = session.endTime,
                phase = session.phase ?: "work",
                durationSeconds = (session.durationMillis / 1000).toInt(),
                elapsedSeconds = (session.durationMillis / 1000).toInt(),
                wasCompleted = true,
            )
            when (val result = apiClient.createSession(dto)) {
                is NetworkResult.Success -> {
                    sessionDao.markSynced(session.id, now)
                }
                is NetworkResult.Error -> Log.e(TAG, "Session sync error: ${result.code}")
                is NetworkResult.NetworkError -> throw result.exception
            }
        }
        Log.d(TAG, "Sessions synced: ${dirtySessions.size}")
    }

    private fun TaskEntity.toDto() = TaskDto(
        id = serverId ?: 0,
        syncId = id,
        title = title,
        description = notes,
        energyLevel = energyLevel.lowercase(),
        isFinished = isCompleted,
        priority = when (priority) {
            "High" -> 3; "Medium" -> 2; "Low" -> 1; else -> 0
        },
        estimatedPomodoros = estimatedPomodoros,
        completedPomodoros = completedPomodoros,
        updatedAt = updatedAt,
        createdDate = createdAt,
        finishDate = completedAt,
    )

    private fun TaskDto.toEntity() = TaskEntity(
        id = syncId.ifEmpty { "server-$id" },
        title = title ?: "",
        notes = description,
        isCompleted = isFinished,
        priority = when (priority) {
            3 -> "High"; 2 -> "Medium"; 1 -> "Low"; else -> "None"
        },
        energyLevel = when (energyLevel?.lowercase()) {
            "deep" -> "Deep"; "light" -> "Light"; else -> "Regular"
        },
        estimatedPomodoros = estimatedPomodoros,
        completedPomodoros = completedPomodoros,
        createdAt = createdDate ?: System.currentTimeMillis(),
        updatedAt = updatedAt,
        completedAt = finishDate,
        serverId = id,
        isDirty = false,
        isDeleted = isDeleted,
        syncedAt = System.currentTimeMillis(),
    )
}
