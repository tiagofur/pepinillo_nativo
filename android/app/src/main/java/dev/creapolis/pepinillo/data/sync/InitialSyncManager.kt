package dev.creapolis.pepinillo.data.sync

import android.util.Log
import dev.creapolis.pepinillo.core.network.FullSyncResponse
import dev.creapolis.pepinillo.core.network.NetworkResult
import dev.creapolis.pepinillo.core.network.PepinilloApiClient
import dev.creapolis.pepinillo.core.network.PomodoroSessionDto
import dev.creapolis.pepinillo.core.network.SubTaskDto
import dev.creapolis.pepinillo.core.network.TaskDto
import dev.creapolis.pepinillo.data.local.dao.DailyStatsDao
import dev.creapolis.pepinillo.data.local.dao.FocusSessionDao
import dev.creapolis.pepinillo.data.local.dao.PreferenceSyncDao
import dev.creapolis.pepinillo.data.local.dao.SubtaskDao
import dev.creapolis.pepinillo.data.local.dao.TaskDao
import dev.creapolis.pepinillo.data.local.entity.FocusSessionEntity
import dev.creapolis.pepinillo.data.local.entity.SubtaskEntity
import dev.creapolis.pepinillo.data.local.entity.TaskEntity
import java.time.Instant
import java.time.ZoneOffset
import java.time.format.DateTimeFormatter
import javax.inject.Inject
import javax.inject.Singleton

private const val TAG = "InitialSyncManager"

@Singleton
class InitialSyncManager @Inject constructor(
    private val apiClient: PepinilloApiClient,
    private val taskDao: TaskDao,
    private val subtaskDao: SubtaskDao,
    private val sessionDao: FocusSessionDao,
    private val dailyStatsDao: DailyStatsDao,
    private val preferenceSyncDao: PreferenceSyncDao,
    private val settingsSyncEngine: SettingsSyncEngine,
    private val syncMetadataStore: SyncMetadataStore,
) {
    sealed class InitialSyncResult {
        data object Success : InitialSyncResult()
        data object NotAuthenticated : InitialSyncResult()
        data class Error(val exception: Exception) : InitialSyncResult()
    }

    /**
     * Pull all data from the server using cursor-paginated /sync/full endpoint.
     * Used on first login when Room is empty, or after [wipeAndSync].
     */
    suspend fun performInitialSync(): InitialSyncResult {
        return try {
            Log.d(TAG, "performInitialSync: STARTING")

            var taskCursor: String? = null
            var sessionCursor: String? = null
            var serverTimestamp: String? = null
            var isFirstPage = true
            var totalTasks = 0
            var totalSessions = 0

            // Phase 1: Pull all tasks (and first page of sessions + settings)
            do {
                val response = apiClient.getFullSync(
                    taskCursor = taskCursor,
                    sessionCursor = if (isFirstPage) null else sessionCursor,
                    limit = 100,
                )

                when (response) {
                    is NetworkResult.Success -> {
                        val data = response.data
                        serverTimestamp = data.serverTimestamp

                        // Process tasks page
                        if (data.tasks.items.isNotEmpty()) {
                            val taskEntities = data.tasks.items.map { it.toEntity() }
                            taskDao.upsertAll(taskEntities)
                            // Process subtasks for each task
                            for (taskDto in data.tasks.items) {
                                if (taskDto.subTasks.isNotEmpty()) {
                                    mergeSubtasks(taskDto.toEntity().id, taskDto.subTasks)
                                }
                            }
                            totalTasks += data.tasks.items.size
                            Log.d(TAG, "performInitialSync: inserted ${data.tasks.items.size} tasks (total=$totalTasks)")
                        }
                        taskCursor = data.tasks.nextCursor

                        if (isFirstPage) {
                            // Process first page of sessions
                            processSessionsPage(data)
                            totalSessions += data.sessions.items.size
                            sessionCursor = data.sessions.nextCursor

                            // Process settings
                            if (data.settings.isNotEmpty()) {
                                Log.d(TAG, "performInitialSync: applying ${data.settings.size} settings")
                                settingsSyncEngine.applyServerPreferences(data.settings)
                            }

                            isFirstPage = false
                        }
                    }

                    is NetworkResult.Error -> {
                        Log.e(TAG, "performInitialSync: API error ${response.code} ${response.message}")
                        if (response.code == 401) return InitialSyncResult.NotAuthenticated
                        return InitialSyncResult.Error(
                            SyncException("Full sync failed: ${response.code} ${response.message}"),
                        )
                    }

                    is NetworkResult.NetworkError -> {
                        Log.e(TAG, "performInitialSync: network error", response.exception)
                        return InitialSyncResult.Error(Exception(response.exception))
                    }
                }
            } while (taskCursor != null)

            // Phase 2: Pull remaining sessions if paginated
            while (sessionCursor != null) {
                val response = apiClient.getFullSync(
                    sessionCursor = sessionCursor,
                    limit = 100,
                )

                when (response) {
                    is NetworkResult.Success -> {
                        val data = response.data
                        processSessionsPage(data)
                        totalSessions += data.sessions.items.size
                        sessionCursor = data.sessions.nextCursor
                        Log.d(TAG, "performInitialSync: inserted ${data.sessions.items.size} sessions (total=$totalSessions)")
                    }

                    is NetworkResult.Error -> {
                        Log.e(TAG, "performInitialSync: session page error ${response.code}")
                        if (response.code == 401) return InitialSyncResult.NotAuthenticated
                        return InitialSyncResult.Error(
                            SyncException("Session sync failed: ${response.code} ${response.message}"),
                        )
                    }

                    is NetworkResult.NetworkError -> {
                        Log.e(TAG, "performInitialSync: session page network error", response.exception)
                        return InitialSyncResult.Error(Exception(response.exception))
                    }
                }
            }

            // Phase 3: Store sync timestamp for future incremental syncs
            serverTimestamp?.let { syncMetadataStore.lastSessionSyncAt = it }

            Log.d(TAG, "performInitialSync: SUCCESS ($totalTasks tasks, $totalSessions sessions)")
            InitialSyncResult.Success
        } catch (e: Exception) {
            Log.e(TAG, "performInitialSync: FAILED", e)
            InitialSyncResult.Error(e)
        }
    }

    /**
     * Wipe all local data and pull fresh from server.
     * Used when user chooses "Use Account Only" in the merge dialog.
     */
    suspend fun wipeAndSync(): InitialSyncResult {
        return try {
            Log.d(TAG, "wipeAndSync: clearing local data")

            // 1. Clear all Room tables
            taskDao.deleteAll()
            subtaskDao.deleteAll()
            sessionDao.deleteAll()
            dailyStatsDao.deleteAll()
            preferenceSyncDao.deleteAll()

            Log.d(TAG, "wipeAndSync: local data cleared, starting full sync")

            // 2. Perform initial sync from server
            performInitialSync()
        } catch (e: Exception) {
            Log.e(TAG, "wipeAndSync: FAILED", e)
            InitialSyncResult.Error(e)
        }
    }

    // ── Private Helpers ──

    private suspend fun processSessionsPage(data: FullSyncResponse) {
        val sessionEntities = data.sessions.items
            .filter { it.id.isNotEmpty() }
            .map { it.toEntity() }
        if (sessionEntities.isNotEmpty()) {
            sessionDao.upsertSessions(sessionEntities)
        }
        // Resolve inbound task links: taskSyncId/taskId → local task UUID
        resolveInboundTaskLinks(data.sessions.items)
    }

    /**
     * For each inbound server session that carries a [PomodoroSessionDto.taskSyncId],
     * look up the corresponding local task and update [FocusSessionEntity.linkedTaskId].
     * Falls back to server-ID-based lookup when taskSyncId is absent but taskId is present.
     */
    private suspend fun resolveInboundTaskLinks(serverSessions: List<PomodoroSessionDto>) {
        var resolved = 0
        for (dto in serverSessions) {
            if (dto.id.isEmpty()) continue
            val localTaskId = when {
                !dto.taskSyncId.isNullOrEmpty() -> {
                    taskDao.getTaskById(dto.taskSyncId)?.id
                }
                dto.taskId != null -> {
                    taskDao.getTaskByServerId(dto.taskId)?.id
                }
                else -> null
            }
            if (localTaskId != null) {
                sessionDao.updateLinkedTaskId(dto.id, localTaskId)
                resolved++
            }
        }
        if (resolved > 0) {
            Log.d(TAG, "resolveInboundTaskLinks: resolved $resolved session→task links")
        }
    }

    private suspend fun mergeSubtasks(localTaskId: String, serverSubtasks: List<SubTaskDto>) {
        subtaskDao.deleteSubtasksForTask(localTaskId)
        val entities = serverSubtasks.mapIndexed { index, dto ->
            SubtaskEntity(
                taskId = localTaskId,
                title = dto.title ?: "",
                isCompleted = dto.isFinished,
                sortOrder = index,
                isDirty = false,
            )
        }
        subtaskDao.insertAll(entities)
    }

    // ── DTO → Entity converters (mirrors SyncEngine patterns) ──

    private fun parseRfc3339(dateString: String): Long {
        return try {
            val instant = Instant.parse(dateString)
            instant.toEpochMilli()
        } catch (e: Exception) {
            0L
        }
    }

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

    private fun mapModeFromServer(serverMode: String): String = when (serverMode.lowercase()) {
        "pomodoro" -> "Pomodoro"
        "flowtime" -> "Flowtime"
        "timeblock" -> "TimeBlock"
        "stopwatch" -> "Stopwatch"
        else -> "Pomodoro"
    }

    private fun mapPhase(serverPhase: String): String = when (serverPhase.lowercase()) {
        "work" -> "Work"
        "short_break" -> "Short Break"
        "long_break" -> "Long Break"
        "flow" -> "Flow"
        "break" -> "Break"
        "check_in" -> "Check In"
        "freeform" -> "Freeform"
        else -> serverPhase
    }

    private fun PomodoroSessionDto.toEntity() = FocusSessionEntity(
        id = id,
        mode = mapModeFromServer(mode),
        startTime = parseRfc3339(startedAt),
        endTime = if (endedAt != null) parseRfc3339(endedAt) else parseRfc3339(startedAt) + (durationSeconds * 1000L),
        durationMillis = durationSeconds * 1000L,
        linkedTaskId = null, // Server taskId is Int, local is String — resolved separately
        phase = mapPhase(phase),
        createdAt = parseRfc3339(createdAt),
        wasCompleted = wasCompleted,
        interruptions = interruptions,
        pauseCount = pauseCount,
        totalPauseMillis = totalPauseSeconds * 1000L,
        pomodoroNumber = pomodoroNumber,
        journalNote = journalNote,
        satisfactionRating = satisfactionRating,
        isDirty = false,
        syncedAt = System.currentTimeMillis(),
    )
}
