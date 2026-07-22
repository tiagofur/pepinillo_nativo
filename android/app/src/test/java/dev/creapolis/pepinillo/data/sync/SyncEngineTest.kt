package dev.creapolis.pepinillo.data.sync

import android.content.Context
import dev.creapolis.pepinillo.core.auth.AuthStore
import dev.creapolis.pepinillo.core.billing.SubscriptionManager
import dev.creapolis.pepinillo.core.billing.SubscriptionState
import dev.creapolis.pepinillo.core.billing.SubscriptionTier
import dev.creapolis.pepinillo.core.network.FocusStatsDto
import dev.creapolis.pepinillo.core.network.NetworkResult
import dev.creapolis.pepinillo.core.network.PepinilloApiClient
import dev.creapolis.pepinillo.core.network.PomodoroSessionDto
import dev.creapolis.pepinillo.core.network.SessionSyncResponse
import dev.creapolis.pepinillo.core.network.TaskDto
import dev.creapolis.pepinillo.core.network.TaskSyncResponse
import dev.creapolis.pepinillo.data.local.dao.DailyStatsDao
import dev.creapolis.pepinillo.data.local.dao.FocusSessionDao
import dev.creapolis.pepinillo.data.local.dao.PreferenceSyncDao
import dev.creapolis.pepinillo.data.local.dao.SubtaskDao
import dev.creapolis.pepinillo.data.local.dao.TaskDao
import dev.creapolis.pepinillo.data.local.entity.DailyStatsEntity
import dev.creapolis.pepinillo.data.local.entity.FocusSessionEntity
import dev.creapolis.pepinillo.data.local.entity.TaskEntity
import dev.creapolis.pepinillo.data.local.preferences.UserPreferences
import dev.creapolis.pepinillo.data.local.preferences.UserPreferencesRepository
import io.mockk.coEvery
import io.mockk.coVerify
import io.mockk.every
import io.mockk.mockk
import io.mockk.slot
import io.mockk.verify
import kotlinx.coroutines.async
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

class SyncEngineTest {

    private lateinit var taskDao: TaskDao
    private lateinit var subtaskDao: SubtaskDao
    private lateinit var sessionDao: FocusSessionDao
    private lateinit var dailyStatsDao: DailyStatsDao
    private lateinit var preferenceSyncDao: PreferenceSyncDao
    private lateinit var userPreferencesRepository: UserPreferencesRepository
    private lateinit var apiClient: PepinilloApiClient
    private lateinit var authStore: AuthStore
    private lateinit var settingsSyncEngine: SettingsSyncEngine
    private lateinit var syncMetadataStore: SyncMetadataStore
    private lateinit var syncStatusManager: SyncStatusManager
    private lateinit var subscriptionManager: SubscriptionManager
    private lateinit var context: Context
    private lateinit var syncLock: SyncLock
    private lateinit var syncEngine: SyncEngine

    @Before
    fun setUp() {
        taskDao = mockk(relaxed = true)
        subtaskDao = mockk(relaxed = true)
        sessionDao = mockk(relaxed = true)
        dailyStatsDao = mockk(relaxed = true)
        preferenceSyncDao = mockk(relaxed = true)
        userPreferencesRepository = mockk(relaxed = true)
        apiClient = mockk(relaxed = true)
        authStore = mockk(relaxed = true)
        settingsSyncEngine = mockk(relaxed = true)
        syncMetadataStore = mockk(relaxed = true)
        syncStatusManager = mockk(relaxed = true)
        subscriptionManager = mockk(relaxed = true)
        context = mockk(relaxed = true)
        syncLock = SyncLock()

        every { userPreferencesRepository.preferences } returns flowOf(UserPreferences())
        coEvery { settingsSyncEngine.syncSettingsImpl() } returns Result.success(Unit)

        // Default: Everywhere+ so existing syncAll tests still reach the sync logic
        every { subscriptionManager.subscriptionState } returns MutableStateFlow(
            SubscriptionState(tier = SubscriptionTier.EVERYWHERE_MONTHLY)
        )

        syncEngine = SyncEngine(
            context = context,
            taskDao = taskDao,
            subtaskDao = subtaskDao,
            sessionDao = sessionDao,
            dailyStatsDao = dailyStatsDao,
            preferenceSyncDao = preferenceSyncDao,
            userPreferencesRepository = userPreferencesRepository,
            apiClient = apiClient,
            authStore = authStore,
            settingsSyncEngine = settingsSyncEngine,
            syncMetadataStore = syncMetadataStore,
            syncStatusManager = syncStatusManager,
            subscriptionManager = subscriptionManager,
            syncLock = syncLock,
        )
    }

    private fun createSyncEngine(): SyncEngine = SyncEngine(
        context = context,
        taskDao = taskDao,
        subtaskDao = subtaskDao,
        sessionDao = sessionDao,
        dailyStatsDao = dailyStatsDao,
        preferenceSyncDao = preferenceSyncDao,
        userPreferencesRepository = userPreferencesRepository,
        apiClient = apiClient,
        authStore = authStore,
        settingsSyncEngine = settingsSyncEngine,
        syncMetadataStore = syncMetadataStore,
        syncStatusManager = syncStatusManager,
        subscriptionManager = subscriptionManager,
        syncLock = syncLock,
    )

    // -----------------------------------------------------------------------
    // syncAll -- skip when anonymous
    // -----------------------------------------------------------------------

    @Test
    fun `syncAll skips when anonymous (no token)`() = runTest {
        every { authStore.getAccessToken() } returns null

        val result = syncEngine.syncAll()
        assertEquals(SyncResult.NotAuthenticated, result)

        // No sync calls should have been made
        coVerify(exactly = 0) { settingsSyncEngine.syncSettingsImpl() }
    }

    // -----------------------------------------------------------------------
    // syncAll -- no-op when canSync = false (Pepinillo+ / FREE)
    // -----------------------------------------------------------------------

    @Test
    fun `syncAll is no-op when canSync is false (PEPINILLO_PLUS)`() = runTest {
        every { authStore.getAccessToken() } returns "valid-token"
        every { subscriptionManager.subscriptionState } returns MutableStateFlow(
            SubscriptionState(tier = SubscriptionTier.PEPINILLO_PLUS)
        )
        // Re-create engine so it picks up the new subscriptionManager state
        syncEngine = createSyncEngine()

        val result = syncEngine.syncAll()

        // Should return Success (no error) but make zero network calls
        assertEquals(SyncResult.Success, result)
        coVerify(exactly = 0) { settingsSyncEngine.syncSettingsImpl() }
        coVerify(exactly = 0) { apiClient.syncTasks(any()) }
        coVerify(exactly = 0) { apiClient.syncSessions(any()) }
    }

    @Test
    fun `syncAll is no-op when canSync is false (FREE)`() = runTest {
        every { authStore.getAccessToken() } returns "valid-token"
        every { subscriptionManager.subscriptionState } returns MutableStateFlow(
            SubscriptionState(tier = SubscriptionTier.FREE)
        )
        syncEngine = createSyncEngine()

        val result = syncEngine.syncAll()

        assertEquals(SyncResult.Success, result)
        coVerify(exactly = 0) { settingsSyncEngine.syncSettingsImpl() }
    }

    @Test
    fun `syncAll proceeds when canSync is true (EVERYWHERE_MONTHLY)`() = runTest {
        every { authStore.getAccessToken() } returns "valid-token"
        every { authStore.getUserId() } returns "user-1"
        every { subscriptionManager.subscriptionState } returns MutableStateFlow(
            SubscriptionState(tier = SubscriptionTier.EVERYWHERE_MONTHLY)
        )
        syncEngine = createSyncEngine()

        coEvery { taskDao.getDirtyTasks() } returns emptyList()
        coEvery { apiClient.getTasks() } returns NetworkResult.Success(emptyList())
        coEvery { sessionDao.getDirtySessions() } returns emptyList()
        coEvery { apiClient.syncSessions(any()) } returns NetworkResult.Success(
            dev.creapolis.pepinillo.core.network.SessionSyncResponse(
                sessions = emptyList(),
                serverTimestamp = "2025-01-01T00:00:00Z"
            )
        )
        coEvery { apiClient.getStats(any(), any()) } returns NetworkResult.Success(emptyList())

        val result = syncEngine.syncAll()

        assertEquals(SyncResult.Success, result)
        coVerify { settingsSyncEngine.syncSettingsImpl() }
    }

    // -----------------------------------------------------------------------
    // syncAll -- calls phases in correct order
    // -----------------------------------------------------------------------

    @Test
    fun `syncAll calls phases in correct order (settings, tasks, sessions, stats)`() = runTest {
        every { authStore.getAccessToken() } returns "valid-token"
        every { authStore.getUserId() } returns "user-1"

        // Setup task sync to return empty
        coEvery { taskDao.getDirtyTasks() } returns emptyList()
        coEvery { apiClient.getTasks() } returns NetworkResult.Success(emptyList())

        // Setup session sync to return empty
        coEvery { sessionDao.getDirtySessions() } returns emptyList()
        coEvery { apiClient.syncSessions(any()) } returns NetworkResult.Success(
            SessionSyncResponse(sessions = emptyList(), serverTimestamp = "2025-01-01T00:00:00Z")
        )

        // Stats - return empty
        coEvery { apiClient.getStats(any(), any()) } returns NetworkResult.Success(emptyList())

        val result = syncEngine.syncAll()
        assertEquals(SyncResult.Success, result)

        // Verify all phases were called
        coVerify { settingsSyncEngine.syncSettingsImpl() }
        coVerify { taskDao.getDirtyTasks() }
        coVerify { sessionDao.getDirtySessions() }
        coVerify { apiClient.getStats(any(), any()) }
    }

    // -----------------------------------------------------------------------
    // syncAll -- auth failure propagated
    // -----------------------------------------------------------------------

    @Test
    fun `syncAll returns NotAuthenticated on auth failure`() = runTest {
        every { authStore.getAccessToken() } returns "valid-token"
        coEvery { settingsSyncEngine.syncSettingsImpl() } returns
            Result.failure(AuthenticationException("401"))

        val result = syncEngine.syncAll()
        assertEquals(SyncResult.NotAuthenticated, result)
    }

    // -----------------------------------------------------------------------
    // syncSessions -- sends dirty sessions and processes response
    // -----------------------------------------------------------------------

    @Test
    fun `syncSessions sends dirty sessions and processes response`() = runTest {
        every { authStore.getUserId() } returns "user-1"
        every { syncMetadataStore.lastSessionSyncAt } returns null

        val dirtySession = FocusSessionEntity(
            id = "session-1",
            mode = "Pomodoro",
            startTime = 1000L,
            endTime = 2000L,
            durationMillis = 1000L,
            isDirty = true,
        )
        coEvery { sessionDao.getDirtySessions() } returns listOf(dirtySession)
        coEvery { sessionDao.getSessionById("session-1") } returns dirtySession
        coEvery { sessionDao.getSessionById("server-session-1") } returns null
        coEvery { taskDao.getTaskById(any()) } returns null

        val serverSession = PomodoroSessionDto(
            id = "server-session-1",
            startedAt = "2025-01-01T00:00:00Z",
            endedAt = "2025-01-01T00:25:00Z",
            mode = "pomodoro",
            phase = "work",
            durationSeconds = 1500,
            createdAt = "2025-01-01T00:00:00Z",
            updatedAt = "2025-01-01T00:00:00Z",
        )
        coEvery { apiClient.syncSessions(any()) } returns NetworkResult.Success(
            SessionSyncResponse(
                sessions = listOf(serverSession),
                serverTimestamp = "2025-06-15T12:00:00Z",
            )
        )

        syncEngine.syncSessions()

        coVerify { sessionDao.upsertSession(any()) }
        coVerify(exactly = 0) { sessionDao.upsertSessions(any()) }
        // Local dirty session was not merged/cleared — must stay dirty and unmarked.
        coVerify(exactly = 0) { sessionDao.markSyncedBatch(any(), any()) }
    }

    @Test
    fun `syncSessions does not overwrite dirty local session when local updatedAt is newer`() = runTest {
        every { authStore.getUserId() } returns "user-1"
        every { syncMetadataStore.lastSessionSyncAt } returns null

        val dirtySession = FocusSessionEntity(
            id = "session-1",
            mode = "Pomodoro",
            startTime = 1_000L,
            endTime = 2_000L,
            durationMillis = 1_000L,
            journalNote = "local journal",
            satisfactionRating = 5,
            createdAt = 1_000L,
            updatedAt = 1_740_000_000_000L,
            isDirty = true,
        )
        coEvery { sessionDao.getDirtySessions() } returns listOf(dirtySession)
        coEvery { sessionDao.getSessionById("session-1") } returns dirtySession
        coEvery { taskDao.getTaskById(any()) } returns null

        val staleServerSession = PomodoroSessionDto(
            id = "session-1",
            startedAt = "2025-01-01T00:00:00Z",
            endedAt = "2025-01-01T00:25:00Z",
            mode = "pomodoro",
            phase = "work",
            durationSeconds = 1500,
            journalNote = null,
            satisfactionRating = null,
            createdAt = "2025-01-01T00:00:00Z",
            updatedAt = "2025-01-01T00:00:00Z",
        )
        coEvery { apiClient.syncSessions(any()) } returns NetworkResult.Success(
            SessionSyncResponse(
                sessions = listOf(staleServerSession),
                serverTimestamp = "2025-06-15T12:00:00Z",
            )
        )

        syncEngine.syncSessions()

        coVerify(exactly = 0) { sessionDao.upsertSession(match { it.id == "session-1" }) }
        coVerify(exactly = 0) { sessionDao.markSyncedBatch(any(), any()) }
    }

    @Test
    fun `syncSessions preserves journal when concurrent server payload is older`() = runTest {
        every { authStore.getUserId() } returns "user-1"
        every { syncMetadataStore.lastSessionSyncAt } returns null

        val journalNote = "deep work on API refactor"
        val dirtySession = FocusSessionEntity(
            id = "session-1",
            mode = "Pomodoro",
            startTime = 1_000L,
            endTime = 2_000L,
            durationMillis = 1_000L,
            journalNote = journalNote,
            satisfactionRating = 4,
            createdAt = 1_000L,
            updatedAt = 1_740_000_000_000L,
            isDirty = true,
        )
        coEvery { sessionDao.getDirtySessions() } returns listOf(dirtySession)
        coEvery { sessionDao.getSessionById("session-1") } returns dirtySession
        coEvery { taskDao.getTaskById(any()) } returns null

        val serverSession = PomodoroSessionDto(
            id = "session-1",
            startedAt = "2025-01-01T00:00:00Z",
            endedAt = "2025-01-01T00:25:00Z",
            mode = "pomodoro",
            phase = "work",
            durationSeconds = 1500,
            journalNote = "stale server copy",
            satisfactionRating = 1,
            createdAt = "2025-01-01T00:00:00Z",
            updatedAt = "2025-01-01T00:00:00Z",
        )
        coEvery { apiClient.syncSessions(any()) } returns NetworkResult.Success(
            SessionSyncResponse(
                sessions = listOf(serverSession),
                serverTimestamp = "2025-06-15T12:00:00Z",
            )
        )

        syncEngine.syncSessions()

        coVerify(exactly = 0) { sessionDao.upsertSession(match { it.journalNote != journalNote }) }
        coVerify(exactly = 0) { sessionDao.markSyncedBatch(any(), any()) }
        assertEquals(journalNote, dirtySession.journalNote)
        assertTrue(dirtySession.isDirty)
    }

    @Test
    fun `syncSessions marks pushed session synced when server merge clears dirty flag`() = runTest {
        every { authStore.getUserId() } returns "user-1"
        every { syncMetadataStore.lastSessionSyncAt } returns null

        val dirtySession = FocusSessionEntity(
            id = "session-1",
            mode = "Pomodoro",
            startTime = 1_000L,
            endTime = 2_000L,
            durationMillis = 1_000L,
            createdAt = 1_000L,
            updatedAt = 1_000L,
            isDirty = true,
        )
        val mergedSession = dirtySession.copy(isDirty = false, syncedAt = 9_999L)
        coEvery { sessionDao.getDirtySessions() } returns listOf(dirtySession)
        coEvery { sessionDao.getSessionById("session-1") } returnsMany listOf(
            dirtySession,
            mergedSession,
        )
        coEvery { taskDao.getTaskById(any()) } returns null

        val serverSession = PomodoroSessionDto(
            id = "session-1",
            startedAt = "2025-06-15T12:00:00Z",
            endedAt = "2025-06-15T12:25:00Z",
            mode = "pomodoro",
            phase = "work",
            durationSeconds = 1500,
            createdAt = "2025-01-01T00:00:00Z",
            updatedAt = "2025-06-15T12:00:00Z",
        )
        coEvery { apiClient.syncSessions(any()) } returns NetworkResult.Success(
            SessionSyncResponse(
                sessions = listOf(serverSession),
                serverTimestamp = "2025-06-15T12:00:00Z",
            )
        )

        syncEngine.syncSessions()

        coVerify { sessionDao.upsertSession(match { it.id == "session-1" && !it.isDirty }) }
        coVerify { sessionDao.markSyncedBatch(listOf("session-1"), any()) }
    }

    // -----------------------------------------------------------------------
    // syncSessions -- stores serverTimestamp
    // -----------------------------------------------------------------------

    @Test
    fun `syncSessions stores serverTimestamp in SyncMetadataStore`() = runTest {
        every { authStore.getUserId() } returns "user-1"
        every { syncMetadataStore.lastSessionSyncAt } returns null

        coEvery { sessionDao.getDirtySessions() } returns emptyList()
        coEvery { apiClient.syncSessions(any()) } returns NetworkResult.Success(
            SessionSyncResponse(
                sessions = emptyList(),
                serverTimestamp = "2025-06-15T12:00:00Z",
            )
        )

        syncEngine.syncSessions()

        verify { syncMetadataStore.lastSessionSyncAt = "2025-06-15T12:00:00Z" }
    }

    // -----------------------------------------------------------------------
    // initialUpload -- collects all local data
    // -----------------------------------------------------------------------

    @Test
    fun `initialUpload collects all local data`() = runTest {
        every { authStore.getAccessToken() } returns "valid-token"
        every { authStore.getOrCreateDeviceId() } returns "device-1"
        every { authStore.getUserId() } returns "user-1"

        val task = TaskEntity(
            id = "task-1",
            title = "Test Task",
            createdAt = 1000L,
            updatedAt = 2000L,
        )
        coEvery { taskDao.getAllTasksSync() } returns listOf(task)
        coEvery { subtaskDao.getSubtasksForTaskSync(any()) } returns emptyList()

        val session = FocusSessionEntity(
            id = "session-1",
            mode = "Pomodoro",
            startTime = 1000L,
            endTime = 2000L,
            durationMillis = 1000L,
        )
        coEvery { sessionDao.getAllSessionsSync() } returns listOf(session)
        coEvery { preferenceSyncDao.getDirtyPreferences() } returns emptyList()

        coEvery { apiClient.initialUpload(any()) } returns NetworkResult.Success(
            dev.creapolis.pepinillo.core.network.InitialUploadResponse(
                tasks = emptyList(),
                sessions = emptyList(),
                settings = emptyList(),
                serverTimestamp = "2025-01-01T00:00:00Z",
                hasExistingData = false,
            )
        )

        val result = syncEngine.initialUpload()
        assertTrue(result is InitialUploadResult.Success)
        assertEquals(false, (result as InitialUploadResult.Success).hasExistingData)

        // Verify all local data was collected
        coVerify { taskDao.getAllTasksSync() }
        coVerify { sessionDao.getAllSessionsSync() }
        coVerify { preferenceSyncDao.getDirtyPreferences() }
    }

    // -----------------------------------------------------------------------
    // initialUpload -- returns hasExistingData correctly
    // -----------------------------------------------------------------------

    @Test
    fun `initialUpload returns hasExistingData correctly`() = runTest {
        every { authStore.getAccessToken() } returns "valid-token"
        every { authStore.getOrCreateDeviceId() } returns "device-1"
        every { authStore.getUserId() } returns "user-1"

        coEvery { taskDao.getAllTasksSync() } returns emptyList()
        coEvery { sessionDao.getAllSessionsSync() } returns emptyList()
        coEvery { preferenceSyncDao.getDirtyPreferences() } returns emptyList()

        coEvery { apiClient.initialUpload(any()) } returns NetworkResult.Success(
            dev.creapolis.pepinillo.core.network.InitialUploadResponse(
                tasks = emptyList(),
                sessions = emptyList(),
                settings = emptyList(),
                serverTimestamp = "2025-01-01T00:00:00Z",
                hasExistingData = true,
            )
        )

        val result = syncEngine.initialUpload()
        assertTrue(result is InitialUploadResult.Success)
        assertEquals(true, (result as InitialUploadResult.Success).hasExistingData)
    }

    // -----------------------------------------------------------------------
    // hasLocalData -- gating with initialPullComplete and dirty rows
    // -----------------------------------------------------------------------

    @Test
    fun `hasLocalData returns true when dirty tasks exist`() = runTest {
        coEvery { taskDao.getDirtyTasks() } returns listOf(
            TaskEntity(id = "t-1", title = "Dirty", createdAt = 1L, updatedAt = 1L, isDirty = true),
        )
        coEvery { sessionDao.getDirtySessions() } returns emptyList()

        assertTrue(syncEngine.hasLocalData())
    }

    @Test
    fun `hasLocalData returns true when dirty sessions exist`() = runTest {
        coEvery { taskDao.getDirtyTasks() } returns emptyList()
        coEvery { sessionDao.getDirtySessions() } returns listOf(
            FocusSessionEntity(
                id = "s-1",
                mode = "Pomodoro",
                startTime = 1000L,
                endTime = 2000L,
                durationMillis = 1000L,
                isDirty = true,
            ),
        )

        assertTrue(syncEngine.hasLocalData())
    }

    @Test
    fun `hasLocalData returns false when initial pull incomplete despite row counts`() = runTest {
        coEvery { taskDao.getDirtyTasks() } returns emptyList()
        coEvery { sessionDao.getDirtySessions() } returns emptyList()
        every { syncMetadataStore.initialPullComplete } returns false
        coEvery { taskDao.getTaskCount() } returns 5
        coEvery { sessionDao.getSessionCount() } returns 3

        assertEquals(false, syncEngine.hasLocalData())
    }

    @Test
    fun `hasLocalData returns true when initial pull complete and data exists`() = runTest {
        coEvery { taskDao.getDirtyTasks() } returns emptyList()
        coEvery { sessionDao.getDirtySessions() } returns emptyList()
        every { syncMetadataStore.initialPullComplete } returns true
        coEvery { taskDao.getTaskCount() } returns 2
        coEvery { sessionDao.getSessionCount() } returns 0

        assertTrue(syncEngine.hasLocalData())
    }

    @Test
    fun `hasLocalData returns false when initial pull complete but database empty`() = runTest {
        coEvery { taskDao.getDirtyTasks() } returns emptyList()
        coEvery { sessionDao.getDirtySessions() } returns emptyList()
        every { syncMetadataStore.initialPullComplete } returns true
        coEvery { taskDao.getTaskCount() } returns 0
        coEvery { sessionDao.getSessionCount() } returns 0

        assertEquals(false, syncEngine.hasLocalData())
    }

    // -----------------------------------------------------------------------
    // initialUpload -- not authenticated
    // -----------------------------------------------------------------------

    @Test
    fun `initialUpload returns NotAuthenticated when no token`() = runTest {
        every { authStore.getAccessToken() } returns null

        val result = syncEngine.initialUpload()
        assertEquals(InitialUploadResult.NotAuthenticated, result)
    }

    // -----------------------------------------------------------------------
    // syncTasks -- auth failure
    // -----------------------------------------------------------------------

    @Test
    fun `syncTasks serializes concurrent calls through SyncLock`() = runTest {
        val dirtyTask = TaskEntity(
            id = "task-1",
            title = "Test",
            createdAt = 1000L,
            updatedAt = 2000L,
            isDirty = true,
        )
        val executionOrder = mutableListOf<String>()
        var activeCalls = 0
        var maxConcurrent = 0

        coEvery { taskDao.getDirtyTasks() } coAnswers {
            executionOrder.add("start")
            activeCalls++
            maxConcurrent = maxOf(maxConcurrent, activeCalls)
            delay(50)
            activeCalls--
            executionOrder.add("end")
            listOf(dirtyTask)
        }
        coEvery { subtaskDao.getSubtasksForTaskSync(any()) } returns emptyList()
        coEvery { apiClient.syncTasks(any()) } returns NetworkResult.Success(
            TaskSyncResponse(tasks = emptyList()),
        )

        val first = async { syncEngine.syncTasks() }
        val second = async { syncEngine.syncTasks() }
        first.await()
        second.await()

        assertEquals(1, maxConcurrent)
        assertEquals(listOf("start", "end", "start", "end"), executionOrder)
        coVerify(exactly = 2) { apiClient.syncTasks(any()) }
    }

    @Test
    fun `syncTasks throws AuthenticationException on 401`() = runTest {
        val dirtyTask = TaskEntity(
            id = "task-1",
            title = "Test",
            createdAt = 1000L,
            updatedAt = 2000L,
            isDirty = true,
        )
        coEvery { taskDao.getDirtyTasks() } returns listOf(dirtyTask)
        coEvery { subtaskDao.getSubtasksForTaskSync(any()) } returns emptyList()
        coEvery { apiClient.syncTasks(any()) } returns NetworkResult.Error(401, "Unauthorized")

        try {
            syncEngine.syncTasks()
            assertTrue("Should have thrown", false)
        } catch (e: AuthenticationException) {
            // Expected
        }
    }

    // -----------------------------------------------------------------------
    // syncDailyStats
    // -----------------------------------------------------------------------

    @Test
    fun `syncDailyStats pushes dirty stats to server and marks them synced`() = runTest {
        val dirtyEntity = DailyStatsEntity(
            date = 1700000000000L,
            totalMinutes = 50,
            sessionsCompleted = 2,
            pomodoroMinutes = 50,
            isDirty = true,
        )
        coEvery { dailyStatsDao.getDirtyStats() } returns listOf(dirtyEntity)
        coEvery { apiClient.upsertStats(any()) } returns NetworkResult.Success(FocusStatsDto())
        coEvery { dailyStatsDao.markSynced(any(), any()) } returns Unit
        coEvery { apiClient.getStats(any(), any()) } returns NetworkResult.Success(emptyList())

        syncEngine.syncDailyStats()

        coVerify(exactly = 1) { apiClient.upsertStats(match { it.count == 2 && it.pomodoroDuration == 3000 }) }
        coVerify(exactly = 1) { dailyStatsDao.markSynced(1700000000000L, any()) }
    }

    @Test
    fun `syncDailyStats applies field-level max and preserves higher local totals`() = runTest {
        coEvery { dailyStatsDao.getDirtyStats() } returns emptyList()
        val existingLocal = DailyStatsEntity(
            date = 1700000000000L,
            totalMinutes = 60,
            sessionsCompleted = 3,
            tasksCompleted = 2,
            longestSessionMinutes = 30,
            pomodoroMinutes = 60,
            isDirty = true,
        )
        coEvery { dailyStatsDao.getStatsForDate(any()) } returns existingLocal
        val serverDto = FocusStatsDto(
            date = "2026-07-22",
            count = 1,
            pomodoroDuration = 1500, // 25 min
        )
        coEvery { apiClient.getStats(any(), any()) } returns NetworkResult.Success(listOf(serverDto))

        val capturedEntity = slot<DailyStatsEntity>()
        coEvery { dailyStatsDao.upsert(capture(capturedEntity)) } returns Unit

        syncEngine.syncDailyStats()

        assertTrue(capturedEntity.isCaptured)
        val saved = capturedEntity.captured
        assertEquals(3, saved.sessionsCompleted) // preserved max(3, 1)
        assertEquals(60, saved.totalMinutes) // preserved max(60, 25)
        assertEquals(60, saved.pomodoroMinutes) // preserved max(60, 25)
        assertEquals(2, saved.tasksCompleted) // preserved tasksCompleted
        assertEquals(30, saved.longestSessionMinutes) // preserved longestSessionMinutes
        assertTrue(saved.isDirty) // remained dirty because local was strictly higher
    }
}
