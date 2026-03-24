package dev.creapolis.pepinillo.data.sync

import android.util.Log
import dev.creapolis.pepinillo.core.auth.AuthStore
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
import dev.creapolis.pepinillo.data.local.entity.DailyStatsEntity
import dev.creapolis.pepinillo.data.local.entity.FocusSessionEntity
import dev.creapolis.pepinillo.data.local.entity.SubtaskEntity
import dev.creapolis.pepinillo.data.local.entity.TaskEntity
import dev.creapolis.pepinillo.data.local.dao.PreferenceSyncDao
import dev.creapolis.pepinillo.data.local.preferences.UserPreferencesRepository
import kotlinx.coroutines.flow.first
import java.time.Instant
import java.time.LocalDate
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

sealed class InitialUploadResult {
    data class Success(val hasExistingData: Boolean) : InitialUploadResult()
    data object NotAuthenticated : InitialUploadResult()
    data class Error(val exception: Exception) : InitialUploadResult()
}

class AuthenticationException(message: String) : Exception(message)
class SyncException(message: String) : Exception(message)

@Singleton
class SyncEngine @Inject constructor(
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
            // Phase 1: Sync settings/preferences first
            settingsSyncEngine.syncSettings().onFailure { e ->
                println("[$TAG]syncSettings: FAILED - ${e::class.simpleName}: ${e.message}")
                if (e is AuthenticationException) throw e
                // Non-fatal: log but continue with other sync phases
            }
            syncTasks()
            syncSessions()
            syncDailyStats()
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

    // ── Local Data Check ──

    suspend fun hasLocalData(): Boolean {
        val taskCount = taskDao.getTaskCount()
        val sessionCount = sessionDao.getSessionCount()
        return taskCount > 0 || sessionCount > 0
    }

    // ── Initial Upload ──

    suspend fun initialUpload(): InitialUploadResult {
        if (authStore.getAccessToken() == null) {
            println("[$TAG]initialUpload: NOT AUTHENTICATED")
            return InitialUploadResult.NotAuthenticated
        }
        return try {
            println("[$TAG]initialUpload: STARTING")
            val deviceId = authStore.getOrCreateDeviceId()
            val userId = authStore.getUserId() ?: ""

            // 1. Collect ALL local data
            val allTasks = taskDao.getAllTasksSync()
            val allSessions = sessionDao.getAllSessionsSync()
            val dirtyPrefs = preferenceSyncDao.getDirtyPreferences()
            val currentPrefs = userPreferencesRepository.preferences.first()

            // 2. Convert to DTOs
            val taskDtos = allTasks.map { task ->
                val subtasks = subtaskDao.getSubtasksForTaskSync(task.id)
                task.toDto(subtasks)
            }
            val sessionDtos = allSessions.map { session ->
                val serverTaskId = session.linkedTaskId?.let { localId ->
                    taskDao.getTaskById(localId)?.serverId
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
                    for (task in allTasks) {
                        val serverTask = response.tasks.find { it.syncId == task.id }
                        val serverId = serverTask?.id ?: (task.serverId ?: 0)
                        taskDao.markSynced(task.id, now, serverId)
                    }

                    val sessionEntities = response.sessions
                        .filter { it.id.isNotEmpty() }
                        .map { it.toEntity() }
                    if (sessionEntities.isNotEmpty()) {
                        sessionDao.upsertSessions(sessionEntities)
                    }
                    for (session in allSessions) {
                        sessionDao.markSynced(session.id, now)
                    }

                    // Apply returned settings
                    settingsSyncEngine.applyServerPreferences(response.settings)
                    preferenceSyncDao.markAllSynced()

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

    internal suspend fun syncTasks() {
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
                val entity = serverTask.toEntity()
                taskDao.insertTask(entity)
                mergeServerSubtasks(entity.id, serverTask.subTasks)
                inserted++
            } else if (!local.isDirty && parseRfc3339(serverTask.updatedAt) > local.updatedAt) {
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
        if (serverSubtasks.isEmpty()) return
        // Replace local subtasks with server subtasks for this task
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

    // ── Session Sync ──

    internal suspend fun syncSessions() {
        val dirtySessions = sessionDao.getDirtySessions()
        val userId = authStore.getUserId() ?: ""

        // Convert dirty sessions to DTOs
        val dirtyDtos = dirtySessions.map { session ->
            val serverTaskId = session.linkedTaskId?.let { localId ->
                taskDao.getTaskById(localId)?.serverId
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

                // Upsert all returned sessions locally
                val entities = response.sessions
                    .filter { it.id.isNotEmpty() }
                    .map { it.toEntity() }
                if (entities.isNotEmpty()) {
                    sessionDao.upsertSessions(entities)
                }
                println("[$TAG]syncSessions: upserted ${entities.size} sessions from server")

                // Mark local dirty sessions as synced
                for (session in dirtySessions) {
                    sessionDao.markSynced(session.id, now)
                }

                // Store server timestamp for next incremental sync
                syncMetadataStore.lastSessionSyncAt = response.serverTimestamp
                println("[$TAG]syncSessions: updated lastSessionSyncAt=${response.serverTimestamp}")
            }
            is NetworkResult.Error -> {
                println("[$TAG]syncSessions ERROR: ${result.code} ${result.message}")
                if (result.code == 401) throw AuthenticationException("syncSessions: 401 Unauthorized")
                throw SyncException("syncSessions failed: ${result.code} ${result.message}")
            }
            is NetworkResult.NetworkError -> {
                println("[$TAG]syncSessions NETWORK ERROR: ${result.exception::class.simpleName}: ${result.exception.message}")
                throw result.exception
            }
        }
    }

    // ── Daily Stats Sync ──

    internal suspend fun syncDailyStats() {
        try {
            // Pull all stats from server for the last 365 days
            val to = LocalDate.now(ZoneOffset.UTC)
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
                    if (result.code == 401) throw AuthenticationException("syncDailyStats: 401 Unauthorized")
                    // Non-fatal for stats
                    Log.w(TAG, "syncDailyStats failed: ${result.code} ${result.message}")
                }
                is NetworkResult.NetworkError -> {
                    Log.w(TAG, "syncDailyStats network error: ${result.exception.message}")
                }
            }
        } catch (e: AuthenticationException) {
            throw e
        } catch (e: Exception) {
            Log.w(TAG, "syncDailyStats failed: ${e.message}")
        }
    }

    private suspend fun mergeServerStats(serverStats: List<FocusStatsDto>) {
        var upserted = 0
        for (dto in serverStats) {
            if (dto.date.isEmpty()) continue
            val date = try {
                LocalDate.parse(dto.date.substringBefore("T"), DateTimeFormatter.ISO_LOCAL_DATE)
            } catch (e: Exception) {
                Log.w(TAG, "Could not parse stats date: ${dto.date}")
                continue
            }
            val startOfDayMillis = date.atStartOfDay(ZoneOffset.UTC).toInstant().toEpochMilli()

            val existing = dailyStatsDao.getStatsForDate(startOfDayMillis)
            if (existing == null || existing.sessionsCompleted == 0) {
                // Only upsert if we don't have local data for this date
                val pomodoroMinutes = dto.pomodoroDuration / 60
                val flowtimeMinutes = dto.flowtimeSeconds / 60
                val timeblockMinutes = dto.timeblockSeconds / 60
                val stopwatchMinutes = dto.stopwatchSeconds / 60
                val totalMinutes = pomodoroMinutes + flowtimeMinutes + timeblockMinutes + stopwatchMinutes

                dailyStatsDao.upsert(DailyStatsEntity(
                    date = startOfDayMillis,
                    totalMinutes = totalMinutes,
                    sessionsCompleted = dto.count,
                    tasksCompleted = 0, // Not tracked by backend stats
                    longestSessionMinutes = 0, // Not tracked by backend stats
                    pomodoroMinutes = pomodoroMinutes,
                    flowMinutes = flowtimeMinutes,
                    blocksMinutes = timeblockMinutes,
                    stopwatchMinutes = stopwatchMinutes,
                ))
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
        mode = mapMode(mode),
        phase = phase ?: "work",
        durationSeconds = (durationMillis / 1000).toInt(),
        elapsedSeconds = (durationMillis / 1000).toInt(),
        wasCompleted = wasCompleted,
        interruptions = interruptions,
        pauseCount = pauseCount,
        totalPauseSeconds = (totalPauseMillis / 1000).toInt(),
        pomodoroNumber = pomodoroNumber,
        satisfactionRating = satisfactionRating,
        journalNote = journalNote,
        createdAt = (createdAt ?: startTime).toRfc3339(),
        updatedAt = (createdAt ?: startTime).toRfc3339(),
    )

    private fun mapMode(localMode: String): String = when (localMode.lowercase()) {
        "pomodoro" -> "pomodoro"
        "flowtime", "flow" -> "flowtime"
        "timeblock", "time block", "timeblocking" -> "timeblock"
        "stopwatch" -> "stopwatch"
        else -> "pomodoro"
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

    private fun mapModeFromServer(serverMode: String): String = when (serverMode.lowercase()) {
        "pomodoro" -> "Pomodoro"
        "flowtime" -> "Flowtime"
        "timeblock" -> "TimeBlock"
        "stopwatch" -> "Stopwatch"
        else -> "Pomodoro"
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
