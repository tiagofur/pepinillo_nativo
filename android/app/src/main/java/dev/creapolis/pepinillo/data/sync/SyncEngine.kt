package dev.creapolis.pepinillo.data.sync

import android.util.Log
import dev.creapolis.pepinillo.core.auth.AuthStore
import dev.creapolis.pepinillo.core.network.NetworkResult
import dev.creapolis.pepinillo.core.network.PepinilloApiClient
import dev.creapolis.pepinillo.core.network.SubTaskDto
import dev.creapolis.pepinillo.core.network.TaskDto
import dev.creapolis.pepinillo.core.network.TaskSyncRequest
import dev.creapolis.pepinillo.data.local.dao.FocusSessionDao
import dev.creapolis.pepinillo.data.local.dao.SubtaskDao
import dev.creapolis.pepinillo.data.local.dao.TaskDao
import dev.creapolis.pepinillo.data.local.entity.SubtaskEntity
import dev.creapolis.pepinillo.data.local.entity.TaskEntity
import dev.creapolis.pepinillo.core.network.PomodoroSessionDto
import java.time.Instant
import java.time.ZoneOffset
import java.time.format.DateTimeFormatter
import javax.inject.Inject
import javax.inject.Singleton

private const val TAG = "SyncEngine"

sealed class SyncResult {
    data object Success : SyncResult()
    data object NotAuthenticated : SyncResult()
    data class Error(val exception: Throwable) : SyncResult()
}

class AuthenticationException(message: String) : Exception(message)
class SyncException(message: String) : Exception(message)

@Singleton
class SyncEngine @Inject constructor(
    private val taskDao: TaskDao,
    private val subtaskDao: SubtaskDao,
    private val sessionDao: FocusSessionDao,
    private val apiClient: PepinilloApiClient,
    private val authStore: AuthStore,
) {
    private fun Long.toRfc3339(): String {
        val instant = Instant.ofEpochMilli(this)
        return instant.atZone(ZoneOffset.UTC).format(DateTimeFormatter.ISO_OFFSET_DATE_TIME)
    }

    private fun parseRfc3339(dateString: String): Long {
        return try {
            val instant = Instant.parse(dateString)
            instant.toEpochMilli()
        } catch (e: Exception) {
            0L
        }
    }

    suspend fun syncAll(): SyncResult {
        if (authStore.getAccessToken() == null) {
            println("[$TAG]syncAll: NOT AUTHENTICATED")
            return SyncResult.NotAuthenticated
        }
        return try {
            println("[$TAG]syncAll: STARTING")
            syncTasks()
            syncSessions()
            println("[$TAG]syncAll: SUCCESS")
            SyncResult.Success
        } catch (e: AuthenticationException) {
            println("[$TAG]syncAll: NOT AUTHENTICATED - ${e.message}")
            SyncResult.NotAuthenticated
        } catch (e: Exception) {
            println("[$TAG]syncAll: FAILED - ${e::class.simpleName}: ${e.message}")
            e.printStackTrace()
            SyncResult.Error(e)
        }
    }

    private suspend fun syncTasks() {
        val dirtyTasks = taskDao.getDirtyTasks()

        if (dirtyTasks.isEmpty()) {
            // Fresh install or no local changes — pull all tasks from server
            pullAllTasks()
            return
        }

        val deletedSyncIds = dirtyTasks
            .filter { it.isDeleted }
            .map { it.id }

        val tasksToSync = dirtyTasks
            .filter { !it.isDeleted }
            .map { task ->
                val subtasks = subtaskDao.getSubtasksForTaskSync(task.id)
                task.toDto(subtasks)
            }

        val request = TaskSyncRequest(
            tasks = tasksToSync,
            deletedSyncIds = deletedSyncIds,
            lastSyncAt = null,
        )

        when (val result = apiClient.syncTasks(request)) {
            is NetworkResult.Success -> {
                val response = result.data
                val now = System.currentTimeMillis()
                println("[$TAG]syncTasks: server returned ${response.tasks.size} tasks")

                for (task in dirtyTasks) {
                    if (task.isDeleted) continue
                    val serverTask = response.tasks.find { it.syncId == task.id }
                    val serverId = serverTask?.id ?: (task.serverId ?: 0)
                    taskDao.markSynced(task.id, now, serverId)
                }

                mergeServerTasks(response.tasks)
                taskDao.purgeDeletedSynced()
            }
            is NetworkResult.Error -> {
                println("[$TAG]syncTasks ERROR: ${result.code} ${result.message}")
                if (result.code == 401) throw AuthenticationException("syncTasks: 401 Unauthorized")
                throw SyncException("syncTasks failed: ${result.code} ${result.message}")
            }
            is NetworkResult.NetworkError -> {
                println("[$TAG]syncTasks NETWORK ERROR: ${result.exception::class.simpleName}: ${result.exception.message}")
                throw result.exception
            }
        }
    }

    private suspend fun syncSessions() {
        val dirtySessions = sessionDao.getDirtySessions()
        if (dirtySessions.isEmpty()) return

        val userId = authStore.getUserId() ?: ""
        val now = System.currentTimeMillis()
        for (session in dirtySessions) {
            // Resolve server-side taskId from linked local task
            val serverTaskId = session.linkedTaskId?.let { localId ->
                taskDao.getTaskById(localId)?.serverId
            }
            val dto = PomodoroSessionDto(
                id = session.id,
                userId = userId,
                taskId = serverTaskId,
                startedAt = session.startTime.toRfc3339(),
                endedAt = session.endTime?.let { if (it > 0L) it.toRfc3339() else null },
                phase = session.phase ?: "work",
                durationSeconds = (session.durationMillis / 1000).toInt(),
                elapsedSeconds = (session.durationMillis / 1000).toInt(),
                wasCompleted = session.wasCompleted,
                interruptions = session.interruptions,
                pauseCount = session.pauseCount,
                totalPauseSeconds = (session.totalPauseMillis / 1000).toInt(),
                pomodoroNumber = session.pomodoroNumber,
                satisfactionRating = session.satisfactionRating,
                journalNote = session.journalNote,
                createdAt = (session.createdAt ?: session.startTime).toRfc3339(),
                updatedAt = (session.createdAt ?: session.startTime).toRfc3339(),
            )
            when (val result = apiClient.createSession(dto)) {
                is NetworkResult.Success -> {
                    sessionDao.markSynced(session.id, now)
                }
                is NetworkResult.Error -> {
                    Log.e(TAG, "Session sync error: ${result.code}")
                    if (result.code == 401) throw AuthenticationException("syncSessions: 401 Unauthorized")
                    throw SyncException("syncSessions failed: ${result.code} ${result.message}")
                }
                is NetworkResult.NetworkError -> throw result.exception
            }
        }
        Log.d(TAG, "Sessions synced: ${dirtySessions.size}")
    }

    private suspend fun pullAllTasks() {
        when (val result = apiClient.getTasks()) {
            is NetworkResult.Success -> {
                val tasks = result.data
                println("[$TAG]pullAllTasks: server returned ${tasks.size} tasks")
                mergeServerTasks(tasks)
            }
            is NetworkResult.Error -> {
                println("[$TAG]pullAllTasks ERROR: ${result.code} ${result.message}")
                if (result.code == 401) throw AuthenticationException("pullAllTasks: 401 Unauthorized")
                throw SyncException("pullAllTasks failed: ${result.code} ${result.message}")
            }
            is NetworkResult.NetworkError -> {
                println("[$TAG]pullAllTasks NETWORK ERROR: ${result.exception::class.simpleName}")
                throw result.exception
            }
        }
    }

    private suspend fun mergeServerTasks(serverTasks: List<TaskDto>) {
        val now = System.currentTimeMillis()
        var inserted = 0
        var updated = 0
        for (serverTask in serverTasks) {
            val localBySyncId = serverTask.syncId.takeIf { it.isNotEmpty() }
                ?.let { taskDao.getTaskById(it) }
            val local = localBySyncId
                ?: taskDao.getTaskByServerId(serverTask.id)
            if (local == null) {
                taskDao.insertTask(serverTask.toEntity())
                inserted++
            } else if (!local.isDirty && parseRfc3339(serverTask.updatedAt) > local.updatedAt) {
                taskDao.updateTask(serverTask.toEntity().copy(
                    id = local.id,
                    isDirty = false,
                    syncedAt = now,
                    serverId = serverTask.id,
                ))
                updated++
            }
        }
        println("[$TAG]mergeServerTasks: inserted=$inserted, updated=$updated")
    }

    private fun TaskEntity.toDto(subtasks: List<SubtaskEntity> = emptyList()) = TaskDto(
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
        updatedAt = updatedAt.toRfc3339(),
        createdDate = createdAt.toRfc3339(),
        finishDate = completedAt?.toRfc3339(),
        trackingMode = "pomodoro",
        completedFlowtimeSessions = 0,
        completedTimeblockSessions = 0,
        completedStopwatchSeconds = 0,
        focusedSecondsPomodoro = 0,
        focusedSecondsFlowtime = 0,
        focusedSecondsTimeblock = 0,
        focusedSecondsStopwatch = 0,
        subTasks = subtasks.map { it.toDto(serverId ?: 0) },
    )

    private fun SubtaskEntity.toDto(serverTaskId: Int) = SubTaskDto(
        id = 0,
        taskId = serverTaskId,
        title = title,
        isFinished = isCompleted,
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
        createdAt = if (createdDate != null) parseRfc3339(createdDate) else System.currentTimeMillis(),
        updatedAt = parseRfc3339(updatedAt),
        completedAt = if (finishDate != null) parseRfc3339(finishDate) else null,
        serverId = id,
        isDirty = false,
        isDeleted = isDeleted,
        syncedAt = System.currentTimeMillis(),
    )
}
