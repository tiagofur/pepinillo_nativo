package dev.creapolis.pepinillo.data.sync

import android.content.Context
import android.util.Log
import dev.creapolis.pepinillo.core.auth.AuthStore
import dev.creapolis.pepinillo.core.billing.SubscriptionManager
import dev.creapolis.pepinillo.core.billing.SubscriptionTier
import dev.creapolis.pepinillo.core.network.NetworkResult
import dev.creapolis.pepinillo.core.network.PepinilloApiClient
import dev.creapolis.pepinillo.core.network.SubTaskDto
import dev.creapolis.pepinillo.core.network.TaskDto
import dev.creapolis.pepinillo.core.network.TaskSyncRequest
import dev.creapolis.pepinillo.core.network.PomodoroSessionDto
import dev.creapolis.pepinillo.core.network.SessionSyncRequest
import dev.creapolis.pepinillo.core.network.FocusStatsDto
import dev.creapolis.pepinillo.core.network.InitialUploadRequest
import dev.creapolis.pepinillo.core.network.PreferenceSyncItem
import dev.creapolis.pepinillo.data.local.dao.DailyStatsDao
import dev.creapolis.pepinillo.data.local.dao.FocusSessionDao
import dev.creapolis.pepinillo.data.local.dao.SubtaskDao
import dev.creapolis.pepinillo.data.local.dao.TaskDao
import dev.creapolis.pepinillo.data.local.dao.TaskSyncUpdate
import dev.creapolis.pepinillo.data.local.entity.DailyStatsEntity
import dev.creapolis.pepinillo.data.local.entity.FocusSessionEntity
import dev.creapolis.pepinillo.data.local.entity.SubtaskEntity
import dev.creapolis.pepinillo.data.local.entity.TaskEntity
import dev.creapolis.pepinillo.data.local.dao.PreferenceSyncDao
import dev.creapolis.pepinillo.data.local.preferences.UserPreferencesRepository
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.flow.first
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.ZoneOffset
import java.time.format.DateTimeFormatter
import javax.inject.Inject
import javax.inject.Singleton

private const val TAG = "SyncEngine"

sealed class SyncResult {
    data object Success : SyncResult()
    data object NotAuthenticated : SyncResult()
    data class TransientError(val exception: Throwable) : SyncResult()
    data class PermanentError(val exception: Throwable) : SyncResult()
}

sealed class InitialUploadResult {
    data class Success(val hasExistingData: Boolean) : InitialUploadResult()
    data object NotAuthenticated : InitialUploadResult()
    data class Error(val exception: Exception) : InitialUploadResult()
}

class AuthenticationException(message: String) : Exception(message)
class SyncException(message: String) : Exception(message)
class PermanentSyncException(message: String) : RuntimeException(message)
class TransientSyncException(message: String) : RuntimeException(message)

/**
 * Classifies an HTTP error code and throws the appropriate exception type.
 * - 401 → [AuthenticationException] (handled separately upstream)
 * - 408, 429 → [TransientSyncException] (timeout / rate-limited, worth retrying)
 * - Other 4xx → [PermanentSyncException] (bad request, won't fix itself on retry)
 * - 5xx → [TransientSyncException] (server issue, likely transient)
 * - Everything else → [TransientSyncException] (default to retry)
 */
fun classifyAndThrowHttpError(code: Int, message: String): Nothing {
    when {
        code == 401 -> throw AuthenticationException("HTTP 401: $message")
        code == 408 || code == 429 -> throw TransientSyncException("HTTP $code: $message")
        code in 400..499 -> throw PermanentSyncException("HTTP $code: $message")
        else -> throw TransientSyncException("HTTP $code: $message")
    }
}

@Singleton
class SyncEngine @Inject constructor(
    @ApplicationContext private val context: Context,
    private val taskDao: TaskDao,
    private val subtaskDao: SubtaskDao,
    private val sessionDao: FocusSessionDao,
    private val dailyStatsDao: DailyStatsDao,
    private val preferenceSyncDao: PreferenceSyncDao,
    private val userPreferencesRepository: UserPreferencesRepository,
    private val apiClient: PepinilloApiClient,
    private val authStore: AuthStore,
    private val settingsSyncEngine: SettingsSyncEngine,
    private val syncMetadataStore: SyncMetadataStore,
    private val syncStatusManager: SyncStatusManager,
    private val subscriptionManager: SubscriptionManager,
    private val syncLock: SyncLock,
) {
    private fun Long.toRfc3339(): String = SyncDateUtils.run { this@toRfc3339.toRfc3339() }

    private fun parseRfc3339(dateString: String?, fallback: Long = 0L): Long =
        SyncDateUtils.parseRfc3339(dateString, fallback)


    suspend fun syncAll(): SyncResult = syncLock.withLock { syncAllImpl() }

    private suspend fun syncAllImpl(): SyncResult {
        if (authStore.getAccessToken() == null) {
            println("[$TAG]syncAll: NOT AUTHENTICATED")
            return SyncResult.NotAuthenticated
        }

        // Gate: Only Everywhere+ users can sync to the backend
        if (!subscriptionManager.subscriptionState.value.canSync) {
            println("[$TAG]syncAll: TIER ${subscriptionManager.subscriptionState.value.tier} - NO BACKEND SYNC ENTITLEMENT")
            return SyncResult.Success
        }

        syncStatusManager.onSyncStarted()
        return try {
            println("[$TAG]syncAll: STARTING")
            // Phase 1: Sync settings/preferences first
            settingsSyncEngine.syncSettingsImpl().onFailure { e ->
                println("[$TAG]syncSettings: FAILED - ${e::class.simpleName}: ${e.message}")
                if (e is AuthenticationException) throw e
                // Non-fatal: log but continue with other sync phases
            }
            // Pre-compute task ID mapping before syncTasks purges soft-deleted rows
            val taskIdMap = buildTaskIdMap()
            syncTasksImpl()
            syncSessionsImpl(taskIdMap)
            syncDailyStatsImpl()
            println("[$TAG]syncAll: SUCCESS")
            syncStatusManager.onSyncSuccess()
            SyncResult.Success
        } catch (e: AuthenticationException) {
            println("[$TAG]syncAll: NOT AUTHENTICATED - ${e.message}")
            syncStatusManager.onSyncError("Not authenticated")
            SyncResult.NotAuthenticated
        } catch (e: PermanentSyncException) {
            println("[$TAG]syncAll: PERMANENT ERROR - ${e.message}")
            syncStatusManager.onSyncError(e.message ?: "Permanent sync error")
            SyncResult.PermanentError(e)
        } catch (e: TransientSyncException) {
            println("[$TAG]syncAll: TRANSIENT ERROR - ${e.message}")
            syncStatusManager.onSyncError(e.message ?: "Sync error, will retry")
            SyncResult.TransientError(e)
        } catch (e: Exception) {
            println("[$TAG]syncAll: FAILED (transient) - ${e::class.simpleName}: ${e.message}")
            e.printStackTrace()
            syncStatusManager.onSyncError(e.message ?: "Unknown sync error")
            SyncResult.TransientError(e)
        }
    }

    // ── Local Data Check ──

    suspend fun hasLocalData(): Boolean {
        // User-created offline data must be uploaded, even if a prior pull failed.
        if (taskDao.getDirtyTasks().isNotEmpty() || sessionDao.getDirtySessions().isNotEmpty()) {
            return true
        }
        // Partial/incomplete initial pull — retry pull, do not upload a broken snapshot.
        if (!syncMetadataStore.initialPullComplete) {
            return false
        }
        val taskCount = taskDao.getTaskCount()
        val sessionCount = sessionDao.getSessionCount()
        return taskCount > 0 || sessionCount > 0
    }

    // ── Initial Upload ──

    suspend fun initialUpload(): InitialUploadResult = syncLock.withLock { initialUploadImpl() }

    private suspend fun initialUploadImpl(): InitialUploadResult {
        if (authStore.getAccessToken() == null) {
            println("[$TAG]initialUpload: NOT AUTHENTICATED")
            return InitialUploadResult.NotAuthenticated
        }

        // initialUpload is allowed for all users (free + pro) to migrate
        // local data to the server on first authenticated session.

        return try {
            println("[$TAG]initialUpload: STARTING")
            val deviceId = authStore.getOrCreateDeviceId()
            val userId = authStore.getUserId() ?: ""

            // 1. Collect ALL local data
            val allTasks = taskDao.getAllTasksSync()
            val allSessions = sessionDao.getAllSessionsSync()
            val dirtyPrefs = preferenceSyncDao.getDirtyPreferences()
            val currentPrefs = userPreferencesRepository.preferences.first()

            // 2. Convert to DTOs — build task ID map for session resolution
            val sessionsByTaskId = allSessions.groupBy { it.linkedTaskId }
            val taskDtos = allTasks.map { task ->
                val subtasks = subtaskDao.getSubtasksForTaskSync(task.id)
                val taskSessions = sessionsByTaskId[task.id] ?: emptyList()
                task.toDto(subtasks, taskSessions)
            }
            val taskIdMap = allTasks
                .filter { it.serverId != null }
                .associate { it.id to it.serverId!! }
            val sessionDtos = allSessions.map { session ->
                val serverTaskId = session.linkedTaskId?.let { localId ->
                    taskIdMap[localId] ?: taskDao.getTaskById(localId)?.serverId
                }
                session.toDto(userId, serverTaskId)
            }
            val settingItems = dirtyPrefs.mapNotNull { entity ->
                val value = readCurrentPreferenceValue(entity.key, currentPrefs) ?: return@mapNotNull null
                PreferenceSyncItem(
                    key = entity.key,
                    value = value,
                    updatedAt = entity.updatedAt.toRfc3339(),
                )
            }

            println("[$TAG]initialUpload: sending ${taskDtos.size} tasks, ${sessionDtos.size} sessions, ${settingItems.size} settings")

            // 3. POST to /sync/initial-upload
            val request = InitialUploadRequest(
                deviceId = deviceId,
                tasks = taskDtos,
                sessions = sessionDtos,
                settings = settingItems,
            )

            when (val result = apiClient.initialUpload(request)) {
                is NetworkResult.Success -> {
                    val response = result.data
                    val now = System.currentTimeMillis()
                    println("[$TAG]initialUpload: server returned ${response.tasks.size} tasks, ${response.sessions.size} sessions, hasExisting=${response.hasExistingData}")

                    // 4. Process response — upsert returned data
                    mergeServerTasks(response.tasks)
                    // O(1) syncId→serverId lookup instead of O(N×M) .find{} per task.
                    val serverIdBySyncId = response.tasks.associate { it.syncId to it.id }
                    val taskUpdates = allTasks.map { task ->
                        TaskSyncUpdate(
                            taskId = task.id,
                            serverId = serverIdBySyncId[task.id] ?: (task.serverId ?: 0),
                        )
                    }
                    if (taskUpdates.isNotEmpty()) {
                        taskDao.markSyncedBatch(taskUpdates, now)
                    }

                    val sessionEntities = response.sessions
                        .filter { it.id.isNotEmpty() }
                        .map { it.toEntity() }
                    if (sessionEntities.isNotEmpty()) {
                        sessionDao.upsertSessions(sessionEntities)
                    }
                    // Resolve inbound task links for server sessions
                    resolveInboundTaskLinks(response.sessions)
                    if (allSessions.isNotEmpty()) {
                        sessionDao.markSyncedBatch(allSessions.map { it.id }, now)
                    }

                    // Apply returned settings
                    settingsSyncEngine.applyServerPreferences(response.settings)
                    for (entity in dirtyPrefs) {
                        preferenceSyncDao.markSyncedIfUnchanged(entity.key, entity.updatedAt)
                    }

                    // Store server timestamp for future incremental sync
                    syncMetadataStore.lastSessionSyncAt = response.serverTimestamp

                    println("[$TAG]initialUpload: SUCCESS, hasExistingData=${response.hasExistingData}")
                    InitialUploadResult.Success(hasExistingData = response.hasExistingData)
                }
                is NetworkResult.Error -> {
                    println("[$TAG]initialUpload ERROR: ${result.code} ${result.message}")
                    if (result.code == 401) return InitialUploadResult.NotAuthenticated
                    InitialUploadResult.Error(SyncException("initialUpload failed: ${result.code} ${result.message}"))
                }
                is NetworkResult.NetworkError -> {
                    println("[$TAG]initialUpload NETWORK ERROR: ${result.exception::class.simpleName}: ${result.exception.message}")
                    InitialUploadResult.Error(Exception(result.exception))
                }
            }
        } catch (e: Exception) {
            println("[$TAG]initialUpload: FAILED - ${e::class.simpleName}: ${e.message}")
            e.printStackTrace()
            InitialUploadResult.Error(e)
        }
    }

    /**
     * Read a single preference value from the current [UserPreferences] snapshot.
     * Mirrors [SettingsSyncEngine.readPreferenceValue] so we can build [PreferenceSyncItem]
     * DTOs without duplicating too much code.
     */
    private fun readCurrentPreferenceValue(
        key: String,
        prefs: dev.creapolis.pepinillo.data.local.preferences.UserPreferences,
    ): String? = when (key) {
        "pomodoro_minutes" -> prefs.pomodoroMinutes.toString()
        "short_break_minutes" -> prefs.shortBreakMinutes.toString()
        "long_break_minutes" -> prefs.longBreakMinutes.toString()
        "sessions_before_long_break" -> prefs.sessionsBeforeLongBreak.toString()
        "time_block_minutes" -> prefs.timeBlockMinutes.toString()
        "auto_start_breaks" -> prefs.autoStartBreaks.toString()
        "auto_start_next_pomodoro" -> prefs.autoStartNextPomodoro.toString()
        "sound_enabled" -> prefs.soundEnabled.toString()
        "vibration_enabled" -> prefs.vibrationEnabled.toString()
        "theme_mode" -> prefs.themeMode.name
        "dynamic_color" -> prefs.dynamicColor.toString()
        "selected_theme" -> prefs.selectedTheme
        "keep_screen_on" -> prefs.keepScreenOn.toString()
        "default_mode" -> prefs.defaultMode
        "show_journal_after_session" -> prefs.showJournalAfterSession.toString()
        "flowtime_min_minutes" -> prefs.flowtimeMinMinutes.toString()
        "midpoint_check_in" -> prefs.midpointCheckIn.toString()
        else -> null
    }

    // ── Task Sync ──

    suspend fun syncTasks() = syncLock.withLock { syncTasksImpl() }

    internal suspend fun syncTasksImpl() {
        val dirtyTasks = taskDao.getDirtyTasks()

        if (dirtyTasks.isEmpty()) {
            // Fresh install or no local changes — pull all tasks from server
            pullAllTasks()
            return
        }

        val deletedSyncIds = dirtyTasks
            .filter { it.isDeleted }
            .map { it.id }

        val allSessions = sessionDao.getAllSessionsSync()
        val sessionsByTaskId = allSessions.groupBy { it.linkedTaskId }
        val tasksToSync = dirtyTasks
            .filter { !it.isDeleted }
            .map { task ->
                val subtasks = subtaskDao.getSubtasksForTaskSync(task.id)
                val taskSessions = sessionsByTaskId[task.id] ?: emptyList()
                task.toDto(subtasks, taskSessions)
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

                // Build a syncId→serverId map ONCE for O(1) lookup instead of O(N×M) .find{} per task.
                val serverIdBySyncId = response.tasks.associate { it.syncId to it.id }
                val updates = dirtyTasks.map { task ->
                    val serverId = if (task.isDeleted) {
                        task.serverId ?: 0
                    } else {
                        serverIdBySyncId[task.id] ?: (task.serverId ?: 0)
                    }
                    TaskSyncUpdate(taskId = task.id, serverId = serverId)
                }
                if (updates.isNotEmpty()) {
                    taskDao.markSyncedBatch(updates, now)
                    for (task in dirtyTasks) {
                        subtaskDao.markSubtasksSynced(task.id)
                        subtaskDao.purgeDeletedSyncedForTask(task.id)
                    }
                }

                mergeServerTasks(response.tasks)
                taskDao.purgeDeletedSynced()
                subtaskDao.purgeDeletedSynced()

            }
            is NetworkResult.Error -> {
                println("[$TAG]syncTasks ERROR: ${result.code} ${result.message}")
                classifyAndThrowHttpError(result.code, "syncTasks: ${result.message}")
            }
            is NetworkResult.NetworkError -> {
                println("[$TAG]syncTasks NETWORK ERROR: ${result.exception::class.simpleName}: ${result.exception.message}")
                throw TransientSyncException("syncTasks network error: ${result.exception.message}")
            }
        }
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
                classifyAndThrowHttpError(result.code, "pullAllTasks: ${result.message}")
            }
            is NetworkResult.NetworkError -> {
                println("[$TAG]pullAllTasks NETWORK ERROR: ${result.exception::class.simpleName}")
                throw TransientSyncException("pullAllTasks network error: ${result.exception.message}")
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

            val serverUpdatedAt = parseRfc3339(
                dateString = serverTask.updatedAt,
                fallback = parseRfc3339(
                    dateString = serverTask.createdDate,
                    fallback = if (local != null && !local.isDirty) local.updatedAt else 0L
                )
            )

            if (local == null) {
                val entity = serverTask.toEntity()
                taskDao.insertTask(entity)
                mergeServerSubtasks(entity.id, serverTask.subTasks)
                inserted++
            } else if (!local.isDirty && serverUpdatedAt >= local.updatedAt) {

                taskDao.updateTask(serverTask.toEntity().copy(
                    id = local.id,
                    isDirty = false,
                    syncedAt = now,
                    serverId = serverTask.id,
                ))
                mergeServerSubtasks(local.id, serverTask.subTasks)
                updated++
            }
        }
        println("[$TAG]mergeServerTasks: inserted=$inserted, updated=$updated")
    }

    private suspend fun mergeServerSubtasks(localTaskId: String, serverSubtasks: List<SubTaskDto>) {
        val existingSubtasks = subtaskDao.getAllSubtasksForTask(localTaskId)
        val remainingLocal = existingSubtasks.toMutableList()
        val toUpsert = mutableListOf<SubtaskEntity>()

        for ((index, dto) in serverSubtasks.withIndex()) {
            val title = dto.title ?: ""
            val serverId = if (dto.id > 0) dto.id else null

            // 1. Try matching by serverId first
            var match = if (serverId != null) {
                remainingLocal.find { it.serverId == serverId }
            } else null

            // 2. Fallback: match by title + sortOrder for non-dirty locals if serverId is not matched
            if (match == null) {
                match = remainingLocal.find { !it.isDirty && it.title == title }
                    ?: remainingLocal.find { !it.isDirty && it.sortOrder == index }
            }

            if (match != null) {
                remainingLocal.remove(match)
                if (match.isDirty) {
                    // Preserve local dirty changes, but update serverId link if available
                    if (match.serverId == null && serverId != null) {
                        toUpsert.add(match.copy(serverId = serverId))
                    }
                } else {
                    // Update non-dirty local subtask while preserving its stable local UUID (id)
                    toUpsert.add(
                        match.copy(
                            title = title,
                            isCompleted = dto.isFinished,
                            sortOrder = index,
                            serverId = serverId ?: match.serverId,
                            isDirty = false,
                            isDeleted = false,
                        ),
                    )
                }
            } else {
                // New subtask from server -> insert with serverId
                toUpsert.add(
                    SubtaskEntity(
                        taskId = localTaskId,
                        title = title,
                        isCompleted = dto.isFinished,
                        sortOrder = index,
                        isDirty = false,
                        isDeleted = false,
                        serverId = serverId,
                    ),
                )
            }
        }

        // 3. Purge non-dirty local subtasks that were removed on server
        for (removed in remainingLocal) {
            if (!removed.isDirty) {
                subtaskDao.hardDeleteById(removed.id)
            }
        }

        if (toUpsert.isNotEmpty()) {
            subtaskDao.insertAll(toUpsert)
        }
    }


    // ── Task ID Mapping ──

    /**
     * Build a snapshot map of local task UUID → server ID for ALL tasks (including
     * soft-deleted ones). Called BEFORE [syncTasks] so that the mapping survives
     * the physical purge that happens at the end of task sync.
     */
    private suspend fun buildTaskIdMap(): Map<String, Int> {
        val allTasks = taskDao.getAllTasksSync() // includes soft-deleted rows
        return allTasks
            .filter { it.serverId != null }
            .associate { it.id to it.serverId!! }
    }

    // ── Session Sync ──

    /**
     * @param precomputedTaskIdMap local task UUID → server ID, built before task
     *   sync purges soft-deleted rows. When null the map is built on-the-fly
     *   (safe for callers that don't run task sync first, e.g. initialUpload).
     */
    suspend fun syncSessions(precomputedTaskIdMap: Map<String, Int>? = null) =
        syncLock.withLock { syncSessionsImpl(precomputedTaskIdMap) }

    internal suspend fun syncSessionsImpl(precomputedTaskIdMap: Map<String, Int>? = null) {
        val dirtySessions = sessionDao.getDirtySessions()
        val userId = authStore.getUserId() ?: ""
        val taskIdMap = precomputedTaskIdMap ?: buildTaskIdMap()

        // Convert dirty sessions to DTOs, using the pre-computed map for task ID
        val dirtyDtos = dirtySessions.map { session ->
            val serverTaskId = session.linkedTaskId?.let { localId ->
                taskIdMap[localId] ?: taskDao.getTaskById(localId)?.serverId
            }
            session.toDto(userId, serverTaskId)
        }

        val request = SessionSyncRequest(
            sessions = dirtyDtos,
            lastSyncAt = syncMetadataStore.lastSessionSyncAt,
        )

        println("[$TAG]syncSessions: pushing ${dirtyDtos.size} dirty, lastSyncAt=${request.lastSyncAt}")

        when (val result = apiClient.syncSessions(request)) {
            is NetworkResult.Success -> {
                val response = result.data
                val now = System.currentTimeMillis()
                println("[$TAG]syncSessions: server returned ${response.sessions.size} sessions")

                mergeServerSessions(response.sessions)

                // Resolve inbound taskSyncId → local task UUID for each server session
                resolveInboundTaskLinks(response.sessions)

                // Mark only pushed sessions that were merged from server or are no longer dirty.
                if (dirtySessions.isNotEmpty()) {
                    val pushedIds = dirtySessions.map { it.id }
                    val toMarkSynced = pushedIds.filter { id ->
                        sessionDao.getSessionById(id)?.isDirty == false
                    }
                    if (toMarkSynced.isNotEmpty()) {
                        sessionDao.markSyncedBatch(toMarkSynced, now)
                    }
                }

                // Store server timestamp for next incremental sync
                syncMetadataStore.lastSessionSyncAt = response.serverTimestamp
                println("[$TAG]syncSessions: updated lastSessionSyncAt=${response.serverTimestamp}")
            }
            is NetworkResult.Error -> {
                println("[$TAG]syncSessions ERROR: ${result.code} ${result.message}")
                classifyAndThrowHttpError(result.code, "syncSessions: ${result.message}")
            }
            is NetworkResult.NetworkError -> {
                println("[$TAG]syncSessions NETWORK ERROR: ${result.exception::class.simpleName}: ${result.exception.message}")
                throw TransientSyncException("syncSessions network error: ${result.exception.message}")
            }
        }
    }

    private suspend fun mergeServerSessions(serverSessions: List<PomodoroSessionDto>) {
        val now = System.currentTimeMillis()
        var inserted = 0
        var updated = 0
        var skipped = 0
        for (serverSession in serverSessions) {
            if (serverSession.id.isEmpty()) continue
            val local = sessionDao.getSessionById(serverSession.id)
            val serverUpdatedAt = serverSession.serverUpdatedAtMillis(
                fallback = if (local != null && !local.isDirty) local.updatedAt else 0L
            )
            if (local == null) {
                sessionDao.upsertSession(serverSession.toEntity())
                inserted++
            } else if (local.isDirty && local.updatedAt > serverUpdatedAt) {
                skipped++
            } else if (serverUpdatedAt >= local.updatedAt || local.isDirty) {
                sessionDao.upsertSession(
                    serverSession.toEntity().copy(
                        id = local.id,
                        linkedTaskId = local.linkedTaskId,
                        isDirty = false,
                        syncedAt = now,
                    ),
                )
                updated++
            } else {
                skipped++
            }
        }
        println("[$TAG]mergeServerSessions: inserted=$inserted, updated=$updated, skipped=$skipped")
    }

    private fun PomodoroSessionDto.serverUpdatedAtMillis(fallback: Long = 0L): Long {
        val parsed = parseRfc3339(updatedAt, fallback = 0L)
        if (parsed > 0L) return parsed
        val created = parseRfc3339(createdAt, fallback = 0L)
        if (created > 0L) return created
        return fallback
    }

    /**
     * For each inbound server session that carries a [PomodoroSessionDto.taskSyncId],
     * look up the corresponding local task and update [FocusSessionEntity.linkedTaskId].
     * Falls back to server-ID-based lookup when taskSyncId is absent but taskId is present.
     */
    private suspend fun resolveInboundTaskLinks(serverSessions: List<PomodoroSessionDto>) {
        // Batch the task lookups instead of one query per session (was N+1).
        val bySyncId = serverSessions.mapNotNull { it.taskSyncId }.filter { it.isNotEmpty() }.distinct()
        val byServerId = serverSessions.mapNotNull { it.taskId }.distinct()

        val syncIdMap: Map<String, String> = if (bySyncId.isNotEmpty()) {
            taskDao.getTasksByIds(bySyncId).associate { it.id to it.id }
        } else emptyMap()
        val serverIdMap: Map<Int, String> = if (byServerId.isNotEmpty()) {
            taskDao.getTasksByServerIds(byServerId).associate { (it.serverId ?: 0) to it.id }
        } else emptyMap()

        var resolved = 0
        for (dto in serverSessions) {
            if (dto.id.isEmpty()) continue
            val localTaskId = when {
                !dto.taskSyncId.isNullOrEmpty() -> syncIdMap[dto.taskSyncId]
                dto.taskId != null -> serverIdMap[dto.taskId]
                else -> null
            }
            if (localTaskId != null) {
                sessionDao.updateLinkedTaskId(dto.id, localTaskId)
                resolved++
            }
        }
        if (resolved > 0) {
            println("[$TAG]resolveInboundTaskLinks: resolved $resolved session→task links")
        }
    }

    // ── Daily Stats Sync ──

    suspend fun syncDailyStats() = syncLock.withLock { syncDailyStatsImpl() }

    internal suspend fun syncDailyStatsImpl() {
        try {
            pushDirtyDailyStats()

            // Pull all stats from server for the last 365 days
            // Use the device's local timezone so date boundaries align with the user's calendar.
            val to = LocalDate.now(ZoneId.systemDefault())
            val from = to.minusDays(365)
            val fromStr = from.format(DateTimeFormatter.ISO_LOCAL_DATE)
            val toStr = to.format(DateTimeFormatter.ISO_LOCAL_DATE)

            when (val result = apiClient.getStats(fromStr, toStr)) {
                is NetworkResult.Success -> {
                    val serverStats = result.data
                    println("[$TAG]syncDailyStats: server returned ${serverStats.size} stats")
                    mergeServerStats(serverStats)
                }
                is NetworkResult.Error -> {
                    println("[$TAG]syncDailyStats ERROR: ${result.code} ${result.message}")
                    classifyAndThrowHttpError(result.code, "syncDailyStats: ${result.message}")
                }
                is NetworkResult.NetworkError -> {
                    Log.w(TAG, "syncDailyStats network error: ${result.exception.message}")
                    throw TransientSyncException("syncDailyStats network error: ${result.exception.message}")
                }
            }
        } catch (e: AuthenticationException) {
            throw e
        } catch (e: PermanentSyncException) {
            throw e
        } catch (e: TransientSyncException) {
            throw e
        } catch (e: Exception) {
            Log.w(TAG, "syncDailyStats failed: ${e.message}")
        }
    }

    private suspend fun pushDirtyDailyStats() {
        val dirtyStatsList = dailyStatsDao.getDirtyStats()
        if (dirtyStatsList.isEmpty()) return

        var pushed = 0
        val now = System.currentTimeMillis()
        for (entity in dirtyStatsList) {
            val dateStr = Instant.ofEpochMilli(entity.date)
                .atZone(ZoneId.systemDefault())
                .format(DateTimeFormatter.ISO_LOCAL_DATE)

            val dto = FocusStatsDto(
                date = dateStr,
                count = entity.sessionsCompleted,
                pomodoros = entity.pomodoroMinutes / 25,
                pomodoroDuration = entity.pomodoroMinutes * 60,
                flowtimeSeconds = entity.flowMinutes * 60,
                timeblockSeconds = entity.blocksMinutes * 60,
                stopwatchSeconds = entity.stopwatchMinutes * 60,
            )

            when (val result = apiClient.upsertStats(dto)) {
                is NetworkResult.Success -> {
                    dailyStatsDao.markSynced(entity.date, now)
                    pushed++
                }
                is NetworkResult.Error -> {
                    Log.w(TAG, "Failed to push dirty daily stat for date $dateStr: ${result.code}")
                    if (result.code == 401) {
                        throw AuthenticationException("pushDirtyDailyStats HTTP 401")
                    }
                }
                is NetworkResult.NetworkError -> {
                    Log.w(TAG, "Network error pushing dirty daily stat for date $dateStr")
                }
            }
        }
        if (pushed > 0) {
            println("[$TAG]pushDirtyDailyStats: pushed $pushed daily stats")
        }
    }

    private suspend fun mergeServerStats(serverStats: List<FocusStatsDto>) {
        var upserted = 0
        val now = System.currentTimeMillis()
        for (dto in serverStats) {
            if (dto.date.isEmpty()) continue
            val date = try {
                LocalDate.parse(dto.date.substringBefore("T"), DateTimeFormatter.ISO_LOCAL_DATE)
            } catch (e: Exception) {
                Log.w(TAG, "Could not parse stats date: ${dto.date}")
                continue
            }
            // Compute start-of-day in the device's local timezone to match SessionRepository.startOfDay().
            // Using UTC here would create duplicate rows for the same calendar date for non-UTC users.
            val startOfDayMillis = date.atStartOfDay(ZoneId.systemDefault()).toInstant().toEpochMilli()

            val existing = dailyStatsDao.getStatsForDate(startOfDayMillis)

            val serverPomodoroMin = dto.pomodoroDuration / 60
            val serverFlowMin = dto.flowtimeSeconds / 60
            val serverBlocksMin = dto.timeblockSeconds / 60
            val serverStopwatchMin = dto.stopwatchSeconds / 60
            val serverTotalMin = serverPomodoroMin + serverFlowMin + serverBlocksMin + serverStopwatchMin

            val pomodoroMinutes = maxOf(serverPomodoroMin, existing?.pomodoroMinutes ?: 0)
            val flowMinutes = maxOf(serverFlowMin, existing?.flowMinutes ?: 0)
            val blocksMinutes = maxOf(serverBlocksMin, existing?.blocksMinutes ?: 0)
            val stopwatchMinutes = maxOf(serverStopwatchMin, existing?.stopwatchMinutes ?: 0)
            val totalMinutes = maxOf(serverTotalMin, existing?.totalMinutes ?: 0)
            val sessionsCompleted = maxOf(dto.count, existing?.sessionsCompleted ?: 0)
            val tasksCompleted = existing?.tasksCompleted ?: 0
            val longestSessionMinutes = existing?.longestSessionMinutes ?: 0

            val isStillDirty = existing?.isDirty == true && (
                existing.sessionsCompleted > dto.count || existing.totalMinutes > serverTotalMin
            )

            val mergedEntity = DailyStatsEntity(
                date = startOfDayMillis,
                totalMinutes = totalMinutes,
                sessionsCompleted = sessionsCompleted,
                tasksCompleted = tasksCompleted,
                longestSessionMinutes = longestSessionMinutes,
                pomodoroMinutes = pomodoroMinutes,
                flowMinutes = flowMinutes,
                blocksMinutes = blocksMinutes,
                stopwatchMinutes = stopwatchMinutes,
                isDirty = isStillDirty,
                syncedAt = now,
            )

            if (existing != mergedEntity) {
                dailyStatsDao.upsert(mergedEntity)
                upserted++
            }
        }
        println("[$TAG]mergeServerStats: upserted=$upserted")
    }

    // ── DTO Converters ──

    private fun FocusSessionEntity.toDto(userId: String, serverTaskId: Int?) = PomodoroSessionDto(
        id = id,
        userId = userId,
        taskId = serverTaskId,
        startedAt = startTime.toRfc3339(),
        endedAt = endTime.let { if (it > 0L) it.toRfc3339() else null },
        mode = FocusModeSyncMapper.toServerMode(mode),
        phase = FocusPhaseSyncMapper.toServerPhase(phase ?: "Work"),
        durationSeconds = ((targetDurationMillis ?: durationMillis) / 1000).toInt(),
        elapsedSeconds = (durationMillis / 1000).toInt(),
        wasCompleted = wasCompleted,
        interruptions = interruptions,
        pauseCount = pauseCount,
        totalPauseSeconds = (totalPauseMillis / 1000).toInt(),
        pomodoroNumber = pomodoroNumber,
        satisfactionRating = satisfactionRating,
        journalNote = journalNote,
        createdAt = createdAt.toRfc3339(),
        updatedAt = updatedAt.toRfc3339(),
    )

    private fun PomodoroSessionDto.toEntity(): FocusSessionEntity {
        val start = parseRfc3339(startedAt, fallback = System.currentTimeMillis())
        val created = parseRfc3339(createdAt, fallback = start)
        val updated = serverUpdatedAtMillis(fallback = created)
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

    private fun TaskEntity.toDto(
        subtasks: List<SubtaskEntity> = emptyList(),
        sessions: List<FocusSessionEntity> = emptyList(),
    ): TaskDto {
        val completedSessions = sessions.filter { it.wasCompleted }
        var focusedSecondsPomodoro = 0
        var focusedSecondsFlowtime = 0
        var focusedSecondsTimeblock = 0
        var focusedSecondsStopwatch = 0
        var completedFlowtimeSessions = 0
        var completedTimeblockSessions = 0
        var completedStopwatchSeconds = 0
        var latestCompletedSessionMode: String? = null

        val sortedSessions = completedSessions.sortedBy { it.startTime }
        for (session in sortedSessions) {
            val focusSeconds = (session.durationMillis / 1000).toInt()
            val serverMode = FocusModeSyncMapper.toServerMode(session.mode)
            latestCompletedSessionMode = serverMode
            when (serverMode) {
                "pomodoro" -> {
                    focusedSecondsPomodoro += focusSeconds
                }
                "flowtime" -> {
                    focusedSecondsFlowtime += focusSeconds
                    completedFlowtimeSessions++
                }
                "timeblock" -> {
                    focusedSecondsTimeblock += focusSeconds
                    completedTimeblockSessions++
                }
                "stopwatch" -> {
                    focusedSecondsStopwatch += focusSeconds
                    completedStopwatchSeconds += focusSeconds
                }
            }
        }
        val totalFocusedSeconds = focusedSecondsPomodoro + focusedSecondsFlowtime + focusedSecondsTimeblock + focusedSecondsStopwatch

        return TaskDto(
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
            trackingMode = latestCompletedSessionMode ?: "pomodoro",
            completedFlowtimeSessions = completedFlowtimeSessions,
            completedTimeblockSessions = completedTimeblockSessions,
            completedStopwatchSeconds = completedStopwatchSeconds,
            focusedSeconds = totalFocusedSeconds,
            focusedSecondsPomodoro = focusedSecondsPomodoro,
            focusedSecondsFlowtime = focusedSecondsFlowtime,
            focusedSecondsTimeblock = focusedSecondsTimeblock,
            focusedSecondsStopwatch = focusedSecondsStopwatch,
            subTasks = subtasks.map { it.toDto(serverId ?: 0) },
        )
    }

    private fun SubtaskEntity.toDto(serverTaskId: Int) = SubTaskDto(
        id = serverId ?: 0,
        taskId = serverTaskId,
        title = title,
        isFinished = isCompleted,
    )


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
}
