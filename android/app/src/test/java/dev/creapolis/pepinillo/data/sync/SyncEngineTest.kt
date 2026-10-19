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

    // -----------------------------------------------------------------------
    // Subtask sync stability and purging
    // -----------------------------------------------------------------------

    @Test
    fun `syncTasks marks subtasks synced and purges soft-deleted subtasks on push success`() = runTest {
        val dirtyTask = TaskEntity(
            id = "task-1",
            title = "Task with subtasks",
            createdAt = 1000L,
            updatedAt = 2000L,
            isDirty = true,
        )
        coEvery { taskDao.getDirtyTasks() } returns listOf(dirtyTask)
        coEvery { subtaskDao.getSubtasksForTaskSync("task-1") } returns emptyList()
        coEvery { apiClient.syncTasks(any()) } returns NetworkResult.Success(
            TaskSyncResponse(tasks = listOf(TaskDto(id = 10, syncId = "task-1", title = "Task with subtasks"))),
        )

        syncEngine.syncTasks()

        coVerify { subtaskDao.markSubtasksSynced("task-1") }
        coVerify { subtaskDao.purgeDeletedSyncedForTask("task-1") }
        coVerify { subtaskDao.purgeDeletedSynced() }
    }

    @Test
    fun `mergeServerSubtasks preserves local subtask UUID across sync rounds`() = runTest {
        val existingSubtask = dev.creapolis.pepinillo.data.local.entity.SubtaskEntity(
            id = "stable-subtask-uuid-123",
            taskId = "task-1",
            title = "Existing Subtask",
            isCompleted = false,
            isDirty = false,
            serverId = 101,
        )
        val localTask = TaskEntity(id = "task-1", title = "Task 1", serverId = 10, updatedAt = 0L, isDirty = false)
        coEvery { taskDao.getTaskById("task-1") } returns localTask
        coEvery { taskDao.getTaskByServerId(10) } returns localTask
        coEvery { subtaskDao.getAllSubtasksForTask("task-1") } returns listOf(existingSubtask)


        val serverSubtask = dev.creapolis.pepinillo.core.network.SubTaskDto(
            id = 101,
            taskId = 10,
            title = "Existing Subtask Updated",
            isFinished = true,
        )
        val serverTask = TaskDto(
            id = 10,
            syncId = "task-1",
            title = "Task 1",
            updatedAt = "2026-07-22T00:00:00Z",
            subTasks = listOf(serverSubtask),
        )

        coEvery { taskDao.getDirtyTasks() } returns emptyList()
        coEvery { apiClient.getTasks() } returns NetworkResult.Success(listOf(serverTask))

        val capturedSubtasks = slot<List<dev.creapolis.pepinillo.data.local.entity.SubtaskEntity>>()
        coEvery { subtaskDao.insertAll(capture(capturedSubtasks)) } returns Unit

        syncEngine.syncTasks()

        assertTrue(capturedSubtasks.isCaptured)
        val merged = capturedSubtasks.captured.first()
        assertEquals("stable-subtask-uuid-123", merged.id)
        assertEquals(101, merged.serverId)
        assertEquals("Existing Subtask Updated", merged.title)
        assertTrue(merged.isCompleted)
    }

    @Test
    fun `mergeServerSubtasks resolves duplicate title subtasks by serverId without collision`() = runTest {
        val subtaskA = dev.creapolis.pepinillo.data.local.entity.SubtaskEntity(
            id = "uuid-a",
            taskId = "task-1",
            title = "Duplicate Title",
            isCompleted = false,
            isDirty = false,
            serverId = 201,
        )
        val subtaskB = dev.creapolis.pepinillo.data.local.entity.SubtaskEntity(
            id = "uuid-b",
            taskId = "task-1",
            title = "Duplicate Title",
            isCompleted = false,
            isDirty = false,
            serverId = 202,
        )
        val localTask = TaskEntity(id = "task-1", title = "Task 1", serverId = 10, updatedAt = 0L, isDirty = false)
        coEvery { taskDao.getTaskById("task-1") } returns localTask
        coEvery { taskDao.getTaskByServerId(10) } returns localTask
        coEvery { subtaskDao.getAllSubtasksForTask("task-1") } returns listOf(subtaskA, subtaskB)


        val serverSubtaskA = dev.creapolis.pepinillo.core.network.SubTaskDto(
            id = 201,
            taskId = 10,
            title = "Duplicate Title",
            isFinished = true,
        )
        val serverSubtaskB = dev.creapolis.pepinillo.core.network.SubTaskDto(
            id = 202,
            taskId = 10,
            title = "Duplicate Title",
            isFinished = false,
        )
        val serverTask = TaskDto(
            id = 10,
            syncId = "task-1",
            title = "Task 1",
            updatedAt = "2026-07-22T00:00:00Z",
            subTasks = listOf(serverSubtaskA, serverSubtaskB),
        )

        coEvery { taskDao.getDirtyTasks() } returns emptyList()
        coEvery { apiClient.getTasks() } returns NetworkResult.Success(listOf(serverTask))

        val capturedSubtasks = slot<List<dev.creapolis.pepinillo.data.local.entity.SubtaskEntity>>()
        coEvery { subtaskDao.insertAll(capture(capturedSubtasks)) } returns Unit

        syncEngine.syncTasks()

        assertTrue(capturedSubtasks.isCaptured)
        val mergedList = capturedSubtasks.captured
        val mergedA = mergedList.find { it.id == "uuid-a" }
        val mergedB = mergedList.find { it.id == "uuid-b" }
        assertTrue(mergedA != null && mergedA.isCompleted)
        assertTrue(mergedB != null && !mergedB.isCompleted)
    }

    @Test
    fun `mergeServerTasks applies server task update when server updatedAt is unparseable and local task is not dirty`() = runTest {
        val localTask = TaskEntity(
            id = "task-100",
            title = "Old Local Title",
            serverId = 100,
            updatedAt = 1720000000000L,
            isDirty = false,
        )
        coEvery { taskDao.getTaskById("task-100") } returns localTask
        coEvery { taskDao.getTaskByServerId(100) } returns localTask
        coEvery { taskDao.getDirtyTasks() } returns emptyList()

        val serverTaskWithInvalidDate = TaskDto(
            id = 100,
            syncId = "task-100",
            title = "Updated Server Title",
            updatedAt = "invalid-date-format",
            createdDate = null,
        )
        coEvery { apiClient.getTasks() } returns NetworkResult.Success(listOf(serverTaskWithInvalidDate))

        val capturedTask = slot<TaskEntity>()
        coEvery { taskDao.updateTask(capture(capturedTask)) } returns Unit

        syncEngine.syncTasks()

        assertTrue(capturedTask.isCaptured)
        assertEquals("Updated Server Title", capturedTask.captured.title)
        assertTrue("updatedAt should not be 0L", capturedTask.captured.updatedAt > 0L)
    }

    @Test
    fun `syncTasks pushes computed focus counters and trackingMode when completed sessions are linked to task`() = runTest {
        val dirtyTask = TaskEntity(
            id = "task-1",
            title = "Task with sessions",
            serverId = 10,
            isDirty = true,
        )
        val sessionPomodoro = FocusSessionEntity(
            id = "s-1",
            mode = "Pomodoro",
            startTime = 1000L,
            endTime = 1501000L,
            durationMillis = 1500_000L, // 1500s
            linkedTaskId = "task-1",
            wasCompleted = true,
        )
        val sessionFlow = FocusSessionEntity(
            id = "s-2",
            mode = "Flow",
            startTime = 2000L,
            endTime = 5002000L,
            durationMillis = 3000_000L, // 3000s
            linkedTaskId = "task-1",
            wasCompleted = true,
        )

        coEvery { taskDao.getDirtyTasks() } returns listOf(dirtyTask)
        coEvery { sessionDao.getAllSessionsSync() } returns listOf(sessionPomodoro, sessionFlow)

        val taskRequestSlot = slot<dev.creapolis.pepinillo.core.network.TaskSyncRequest>()
        coEvery { apiClient.syncTasks(capture(taskRequestSlot)) } returns NetworkResult.Success(TaskSyncResponse(tasks = emptyList()))

        syncEngine.syncTasks()

        assertTrue(taskRequestSlot.isCaptured)
        val pushedTask = taskRequestSlot.captured.tasks[0]
        assertEquals(1500, pushedTask.focusedSecondsPomodoro)
        assertEquals(3000, pushedTask.focusedSecondsFlowtime)
        assertEquals(1, pushedTask.completedFlowtimeSessions)
        assertEquals(4500, pushedTask.focusedSeconds)
        assertEquals("flowtime", pushedTask.trackingMode)
    }

    @Test
    fun `pulling sessions preserves targetDurationMillis and sets effective durationMillis`() = runTest {
        val serverSession = PomodoroSessionDto(
            id = "s-100",
            durationSeconds = 1500,
            elapsedSeconds = 1200,
            startedAt = "2026-07-22T00:00:00Z",
            createdAt = "2026-07-22T00:00:00Z",
            updatedAt = "2026-07-22T00:00:00Z",
        )
        coEvery { sessionDao.getDirtySessions() } returns emptyList()
        coEvery { apiClient.syncSessions(any()) } returns NetworkResult.Success(SessionSyncResponse(sessions = listOf(serverSession), serverTimestamp = "2026-07-22T00:00:00Z"))

        val capturedSession = slot<FocusSessionEntity>()
        coEvery { sessionDao.upsertSession(capture(capturedSession)) } returns Unit

        syncEngine.syncSessions()

        assertTrue(capturedSession.isCaptured)
        val savedSession = capturedSession.captured
        assertEquals(1500_000L, savedSession.targetDurationMillis)
        assertEquals(1200_000L, savedSession.durationMillis)
    }

    @Test
    fun `pushing session populates durationSeconds from targetDurationMillis and elapsedSeconds from durationMillis`() = runTest {
        val sessionEntity = FocusSessionEntity(
            id = "s-200",
            mode = "Pomodoro",
            startTime = 1000L,
            endTime = 1201000L,
            durationMillis = 1200_000L,
            targetDurationMillis = 1500_000L,
            isDirty = true,
        )
        coEvery { sessionDao.getDirtySessions() } returns listOf(sessionEntity)

        val sessionRequestSlot = slot<dev.creapolis.pepinillo.core.network.SessionSyncRequest>()
        coEvery { apiClient.syncSessions(capture(sessionRequestSlot)) } returns NetworkResult.Success(SessionSyncResponse(sessions = emptyList(), serverTimestamp = "2026-07-22T00:00:00Z"))

        syncEngine.syncSessions()

        assertTrue(sessionRequestSlot.isCaptured)
        val pushedSession = sessionRequestSlot.captured.sessions[0]
        assertEquals(1500, pushedSession.durationSeconds)
        assertEquals(1200, pushedSession.elapsedSeconds)
    }

    // -----------------------------------------------------------------------
    // hasServerData (merge pre-check, B1 contract)
    // -----------------------------------------------------------------------

    @Test
    fun `hasServerData returns true when server has data`() = runTest {
        coEvery { apiClient.hasServerData() } returns NetworkResult.Success(true)

        assertEquals(true, syncEngine.hasServerData())
    }

    @Test
    fun `hasServerData returns false when account is empty`() = runTest {
        coEvery { apiClient.hasServerData() } returns NetworkResult.Success(false)

        assertEquals(false, syncEngine.hasServerData())
    }

    @Test
    fun `hasServerData returns null on transport error`() = runTest {
        coEvery { apiClient.hasServerData() } returns NetworkResult.Error(500, "boom")

        assertEquals(null, syncEngine.hasServerData())
    }

    // -----------------------------------------------------------------------
    // syncTasks per-item acks (A3)
    // -----------------------------------------------------------------------

    @Test
    fun `syncTasks marks only server-accepted rows as synced`() = runTest {
        val accepted = TaskEntity(id = "t-applied", title = "A", updatedAt = 2000L, isDirty = true)
        val untouched = TaskEntity(id = "t-other", title = "B", updatedAt = 2000L, isDirty = true)
        coEvery { taskDao.getDirtyTasks() } returns listOf(accepted, untouched)
        coEvery { subtaskDao.getSubtasksForTaskSync(any()) } returns emptyList()
        coEvery { sessionDao.getAllSessionsSync() } returns emptyList()
        coEvery { apiClient.syncTasks(any()) } returns NetworkResult.Success(
            TaskSyncResponse(
                tasks = emptyList(),
                appliedSyncIds = listOf("t-applied"),
                rejectedSyncIds = emptyList(),
            ),
        )

        syncEngine.syncTasks()

        coVerify {
            taskDao.markSyncedBatch(
                match { updates -> updates.map { it.taskId } == listOf("t-applied") },
                any(),
            )
        }
    }

    @Test
    fun `syncTasks applies server version for LWW-rejected rows`() = runTest {
        val local = TaskEntity(id = "t-rej", title = "Local stale", updatedAt = 1000L, isDirty = true)
        val serverDto = TaskDto(
            id = 7,
            syncId = "t-rej",
            title = "Server newer",
            updatedAt = "2026-01-02T00:00:00Z",
        )
        coEvery { taskDao.getDirtyTasks() } returns listOf(local)
        coEvery { subtaskDao.getSubtasksForTaskSync(any()) } returns emptyList()
        coEvery { sessionDao.getAllSessionsSync() } returns emptyList()
        coEvery { apiClient.syncTasks(any()) } returns NetworkResult.Success(
            TaskSyncResponse(
                tasks = listOf(serverDto),
                appliedSyncIds = emptyList(),
                rejectedSyncIds = listOf("t-rej"),
            ),
        )
        // After the engine releases the dirty claim, the merge reads the clean row.
        coEvery { taskDao.getTaskById("t-rej") } returns local.copy(isDirty = false)

        syncEngine.syncTasks()

        // 1. Dirty claim released before the merge.
        coVerify {
            taskDao.updateTask(match { it.id == "t-rej" && it.title == "Local stale" && !it.isDirty })
        }
        // 2. Authoritative server copy applied by the merge.
        coVerify {
            taskDao.updateTask(match { it.id == "t-rej" && it.title == "Server newer" && !it.isDirty })
        }
        // 3. Rejected row excluded from the batch mark (the merge already synced it).
        coVerify(exactly = 0) {
            taskDao.markSyncedBatch(match { updates -> updates.any { it.taskId == "t-rej" } }, any())
        }
    }

    // -----------------------------------------------------------------------
    // mergeServerTasks full-row semantics (A2)
    // -----------------------------------------------------------------------

    @Test
    fun `mergeServerTasks lets server nulls clear local optional fields`() = runTest {
        coEvery { taskDao.getDirtyTasks() } returns emptyList()
        val local = TaskEntity(
            id = "t-1",
            title = "T",
            dueDate = 1700000000000L,
            recurrenceRule = "FREQ=DAILY",
            recurringTemplateID = "tpl",
            sortOrder = 5,
            updatedAt = 1000L,
            isDirty = false,
        )
        val serverDto = TaskDto(
            id = 3,
            syncId = "t-1",
            title = "T",
            dueDate = null,
            recurrenceRule = null,
            recurringTemplateId = null,
            sortOrder = 0,
            updatedAt = "2026-01-02T00:00:00Z",
        )
        coEvery { apiClient.getTasks() } returns NetworkResult.Success(listOf(serverDto))
        coEvery { taskDao.getTaskById("t-1") } returns local

        syncEngine.syncTasks()

        coVerify {
            taskDao.updateTask(
                match {
                    it.dueDate == null &&
                        it.recurrenceRule == null &&
                        it.recurringTemplateID == null &&
                        it.sortOrder == 0
                },
            )
        }
    }

    // -----------------------------------------------------------------------
    // initialUpload converges to merged server state
    // -----------------------------------------------------------------------

    @Test
    fun `initialUpload upserts merged server tasks`() = runTest {
        every { authStore.getAccessToken() } returns "valid-token"
        every { authStore.getOrCreateDeviceId() } returns "device-1"
        every { authStore.getUserId() } returns "user-1"
        coEvery { taskDao.getAllTasksSync() } returns emptyList()
        coEvery { sessionDao.getAllSessionsSync() } returns emptyList()
        coEvery { preferenceSyncDao.getDirtyPreferences() } returns emptyList()
        val serverDto = TaskDto(
            id = 9,
            syncId = "srv-1",
            title = "Server task",
            updatedAt = "2026-01-02T00:00:00Z",
        )
        coEvery { apiClient.initialUpload(any()) } returns NetworkResult.Success(
            dev.creapolis.pepinillo.core.network.InitialUploadResponse(
                tasks = listOf(serverDto),
                sessions = emptyList(),
                settings = emptyList(),
                serverTimestamp = "2026-01-02T00:00:00Z",
                hasExistingData = true,
            ),
        )

        val result = syncEngine.initialUpload()

        assertTrue(result is InitialUploadResult.Success)
        coVerify { taskDao.upsertAll(match { list -> list.any { it.id == "srv-1" && it.title == "Server task" } }) }
    }
}

