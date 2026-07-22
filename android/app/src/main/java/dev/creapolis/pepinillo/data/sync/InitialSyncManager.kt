package dev.creapolis.pepinillo.data.sync

import android.util.Log
import dev.creapolis.pepinillo.core.network.FullSyncResponse
import dev.creapolis.pepinillo.core.network.NetworkResult
import dev.creapolis.pepinillo.core.network.PepinilloApiClient
import dev.creapolis.pepinillo.core.network.PomodoroSessionDto
import dev.creapolis.pepinillo.core.network.PreferenceSyncItem
import dev.creapolis.pepinillo.core.network.SubTaskDto
import dev.creapolis.pepinillo.core.network.TaskDto
import dev.creapolis.pepinillo.data.local.PepinilloDatabase
import dev.creapolis.pepinillo.data.local.dao.TaskDao
import dev.creapolis.pepinillo.data.local.dao.FocusSessionDao
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
    private val database: PepinilloDatabase,
    private val taskDao: TaskDao,
    private val sessionDao: FocusSessionDao,
    private val settingsSyncEngine: SettingsSyncEngine,
    private val syncMetadataStore: SyncMetadataStore,
) {
    sealed class InitialSyncResult {
        data object Success : InitialSyncResult()
        data object NotAuthenticated : InitialSyncResult()
        data class Error(val exception: Exception) : InitialSyncResult()
    }

    private sealed class FetchResult {
        data class Success(val data: FullSyncFetchResult) : FetchResult()
        data object NotAuthenticated : FetchResult()
        data class Error(val exception: Exception) : FetchResult()
    }

    private data class FullSyncFetchResult(
        val tasks: List<TaskDto>,
        val sessions: List<PomodoroSessionDto>,
        val settings: List<PreferenceSyncItem>,
        val serverTimestamp: String?,
    )

    /**
     * Pull all data from the server using cursor-paginated /sync/full endpoint.
     * Used on first login when Room is empty, or after [wipeAndSync].
     *
     * All pages are fetched into memory first; the database is updated in a single
     * [PepinilloDatabase.replaceSyncSnapshot] transaction only after a full download.
     */
    suspend fun performInitialSync(): InitialSyncResult {
        return try {
            Log.d(TAG, "performInitialSync: STARTING")
            when (val fetch = fetchAllFullSyncPages()) {
                is FetchResult.Success -> applyFetchedSnapshot(fetch.data, "performInitialSync")
                is FetchResult.NotAuthenticated -> InitialSyncResult.NotAuthenticated
                is FetchResult.Error -> InitialSyncResult.Error(fetch.exception)
            }
        } catch (e: Exception) {
            Log.e(TAG, "performInitialSync: FAILED", e)
            InitialSyncResult.Error(e)
        }
    }

    /**
     * Wipe all local data and pull fresh from server.
     * Used when user chooses "Use Account Only" in the merge dialog.
     *
     * Download-then-swap: ALL server pages are fetched into memory first. Local
     * storage is only replaced after a successful full download via
     * [PepinilloDatabase.replaceSyncSnapshot]. A failure at any point during the
     * download returns an error and leaves local data completely intact.
     */
    suspend fun wipeAndSync(): InitialSyncResult {
        return try {
            Log.d(TAG, "wipeAndSync: STARTING")
            when (val fetch = fetchAllFullSyncPages()) {
                is FetchResult.Success -> applyFetchedSnapshot(fetch.data, "wipeAndSync")
                is FetchResult.NotAuthenticated -> InitialSyncResult.NotAuthenticated
                is FetchResult.Error -> InitialSyncResult.Error(fetch.exception)
            }
        } catch (e: Exception) {
            Log.e(TAG, "wipeAndSync: FAILED", e)
            InitialSyncResult.Error(e)
        }
    }

    /**
     * Fetch every page from /sync/full into memory. No database writes occur here.
     *
     * Per-stream "done" flags prevent asymmetric pagination from re-requesting a
     * finished stream: once a stream reports hasMore=false its cursor is kept null
     * so the server does not restart it from page 1, which would produce duplicate
     * items accumulated across pages.
     */
    private suspend fun fetchAllFullSyncPages(): FetchResult {
        val allServerTasks = mutableListOf<TaskDto>()
        val allServerSessions = mutableListOf<PomodoroSessionDto>()
        var serverSettings = emptyList<PreferenceSyncItem>()
        var serverTimestamp: String? = null

        var taskCursor: String? = null
        var sessionCursor: String? = null
        var isFirstPage = true
        var tasksDone = false
        var sessionsDone = false
        var hasMoreData = true

        while (hasMoreData) {
            val response = apiClient.getFullSync(
                taskCursor = if (tasksDone) null else taskCursor,
                sessionCursor = if (tasksDone) sessionCursor else if (isFirstPage) null else sessionCursor,
                limit = 100,
            )

            when (response) {
                is NetworkResult.Success -> {
                    val data = response.data
                    serverTimestamp = data.serverTimestamp

                    if (!tasksDone) {
                        allServerTasks.addAll(data.tasks.items)
                        tasksDone = !data.tasks.hasMore
                        taskCursor = if (tasksDone) null else data.tasks.nextCursor
                    }

                    if (!sessionsDone) {
                        if (isFirstPage || tasksDone) {
                            allServerSessions.addAll(data.sessions.items)
                            sessionsDone = !data.sessions.hasMore
                            sessionCursor = if (sessionsDone) null else data.sessions.nextCursor
                        }
                    }

                    if (isFirstPage) {
                        serverSettings = data.settings
                        isFirstPage = false
                    }

                    hasMoreData = !tasksDone || !sessionsDone
                }

                is NetworkResult.Error -> {
                    Log.e(TAG, "fetchAllFullSyncPages: API error ${response.code} ${response.message}")
                    if (response.code == 401) return FetchResult.NotAuthenticated
                    return FetchResult.Error(
                        SyncException("Full sync failed: ${response.code} ${response.message}"),
                    )
                }

                is NetworkResult.NetworkError -> {
                    Log.e(TAG, "fetchAllFullSyncPages: network error", response.exception)
                    return FetchResult.Error(Exception(response.exception))
                }
            }
        }

        return FetchResult.Success(
            FullSyncFetchResult(
                tasks = allServerTasks,
                sessions = allServerSessions,
                settings = serverSettings,
                serverTimestamp = serverTimestamp,
            ),
        )
    }

    /**
     * Apply a fully-fetched server snapshot atomically, then resolve session links
     * and settings outside the wipe/upsert transaction.
     */
    private suspend fun applyFetchedSnapshot(
        fetchResult: FullSyncFetchResult,
        logPrefix: String,
    ): InitialSyncResult {
        val taskEntities = fetchResult.tasks.map { it.toEntity() }
        val subtaskEntities = buildSubtaskEntities(fetchResult.tasks)
        val sessionEntities = fetchResult.sessions
            .filter { it.id.isNotEmpty() }
            .map { it.toEntity() }

        Log.d(
            TAG,
            "$logPrefix: applying snapshot (${taskEntities.size} tasks, ${sessionEntities.size} sessions)",
        )

        database.replaceSyncSnapshot(taskEntities, subtaskEntities, sessionEntities)

        resolveInboundTaskLinks(fetchResult.sessions)

        if (fetchResult.settings.isNotEmpty()) {
            Log.d(TAG, "$logPrefix: applying ${fetchResult.settings.size} settings")
            settingsSyncEngine.applyServerPreferences(fetchResult.settings)
        }

        fetchResult.serverTimestamp?.let { syncMetadataStore.lastSessionSyncAt = it }
        syncMetadataStore.initialPullComplete = true

        Log.d(TAG, "$logPrefix: SUCCESS")
        return InitialSyncResult.Success
    }

    private fun buildSubtaskEntities(tasks: List<TaskDto>): List<SubtaskEntity> {
        return tasks.flatMap { taskDto ->
            val localTaskId = taskDto.toEntity().id
            taskDto.subTasks.mapIndexed { index, dto ->
                SubtaskEntity(
                    taskId = localTaskId,
                    title = dto.title ?: "",
                    isCompleted = dto.isFinished,
                    sortOrder = index,
                    isDirty = false,
                    serverId = if (dto.id > 0) dto.id else null,
                )

            }
        }
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

    // ── DTO → Entity converters (mirrors SyncEngine patterns) ──

    private fun parseRfc3339(dateString: String?, fallback: Long = 0L): Long =
        SyncDateUtils.parseRfc3339(dateString, fallback)

    private fun TaskDto.toEntity(): TaskEntity {
        val created = if (createdDate != null) parseRfc3339(createdDate, fallback = System.currentTimeMillis()) else System.currentTimeMillis()
        val updated = parseRfc3339(updatedAt, fallback = created)
        return TaskEntity(
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
            createdAt = created,
            updatedAt = updated,
            completedAt = if (finishDate != null) parseRfc3339(finishDate, fallback = System.currentTimeMillis()) else null,
            serverId = id,
            isDirty = false,
            isDeleted = isDeleted,
            syncedAt = System.currentTimeMillis(),
        )
    }

    private fun PomodoroSessionDto.toEntity(): FocusSessionEntity {
        val start = parseRfc3339(startedAt, fallback = System.currentTimeMillis())
        val created = parseRfc3339(createdAt, fallback = start)
        val updated = parseRfc3339(updatedAt, fallback = created)
        val effectiveDurationSeconds = if (elapsedSeconds > 0) elapsedSeconds else durationSeconds
        return FocusSessionEntity(
            id = id,
            mode = FocusModeSyncMapper.toLocalMode(mode),
            startTime = start,
            endTime = if (endedAt != null) parseRfc3339(endedAt, fallback = start + (effectiveDurationSeconds * 1000L)) else start + (effectiveDurationSeconds * 1000L),
            durationMillis = effectiveDurationSeconds * 1000L,
            linkedTaskId = null, // Server taskId is Int, local is String — resolved separately
            phase = FocusPhaseSyncMapper.toLocalPhase(phase),
            createdAt = created,
            updatedAt = updated,
            wasCompleted = wasCompleted,
            interruptions = interruptions,
            pauseCount = pauseCount,
            totalPauseMillis = totalPauseSeconds * 1000L,
            pomodoroNumber = pomodoroNumber,
            journalNote = journalNote,
            satisfactionRating = satisfactionRating,
            targetDurationMillis = if (durationSeconds > 0) durationSeconds * 1000L else null,
            isDirty = false,
            syncedAt = System.currentTimeMillis(),
        )
    }
}