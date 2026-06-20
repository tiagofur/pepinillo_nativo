package dev.creapolis.pepinillo.data.sync

import android.content.Context
import dev.creapolis.pepinillo.core.auth.AuthStore
import dev.creapolis.pepinillo.core.billing.SubscriptionManager
import dev.creapolis.pepinillo.core.billing.SubscriptionState
import dev.creapolis.pepinillo.core.billing.SubscriptionTier
import dev.creapolis.pepinillo.core.network.NetworkResult
import dev.creapolis.pepinillo.core.network.PepinilloApiClient
import dev.creapolis.pepinillo.core.network.PomodoroSessionDto
import dev.creapolis.pepinillo.core.network.SessionSyncResponse
import dev.creapolis.pepinillo.core.network.TaskDto
import dev.creapolis.pepinillo.core.network.TaskSyncResponse
import dev.creapolis.pepinillo.core.network.FocusStatsDto
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
import io.mockk.verify
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import java.util.TimeZone

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

        every { userPreferencesRepository.preferences } returns flowOf(UserPreferences())
        // W-4: SyncEngine resolves the persisted timezone via getOrInitUserTimezone() for
        // day-key computations; stub it so the stats path does not throw ZoneId.of("").
        coEvery { userPreferencesRepository.getOrInitUserTimezone() } returns TimeZone.getDefault().id
        // B-C9: syncDailyStatsPush reads dirty stats via getAllDaysWithSessions(); default
        // to empty so the push phase is a no-op in the existing phase-ordering tests.
        every { dailyStatsDao.getAllDaysWithSessions() } returns flowOf(emptyList())
        coEvery { settingsSyncEngine.syncSettings() } returns Result.success(Unit)

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
        )
    }

    // -----------------------------------------------------------------------
    // syncAll -- skip when anonymous
    // -----------------------------------------------------------------------

    @Test
    fun `syncAll skips when anonymous (no token)`() = runTest {
        every { authStore.getAccessToken() } returns null

        val result = syncEngine.syncAll()
        assertEquals(SyncResult.NotAuthenticated, result)

        // No sync calls should have been made
        coVerify(exactly = 0) { settingsSyncEngine.syncSettings() }
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
        )

        val result = syncEngine.syncAll()

        // Should return Success (no error) but make zero network calls
        assertEquals(SyncResult.Success, result)
        coVerify(exactly = 0) { settingsSyncEngine.syncSettings() }
        coVerify(exactly = 0) { apiClient.syncTasks(any()) }
        coVerify(exactly = 0) { apiClient.syncSessions(any()) }
    }

    @Test
    fun `syncAll is no-op when canSync is false (FREE)`() = runTest {
        every { authStore.getAccessToken() } returns "valid-token"
        every { subscriptionManager.subscriptionState } returns MutableStateFlow(
            SubscriptionState(tier = SubscriptionTier.FREE)
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
        )

        val result = syncEngine.syncAll()

        assertEquals(SyncResult.Success, result)
        coVerify(exactly = 0) { settingsSyncEngine.syncSettings() }
    }

    @Test
    fun `syncAll proceeds when canSync is true (EVERYWHERE_MONTHLY)`() = runTest {
        every { authStore.getAccessToken() } returns "valid-token"
        every { authStore.getUserId() } returns "user-1"
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
        )

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
        coVerify { settingsSyncEngine.syncSettings() }
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
        coVerify { settingsSyncEngine.syncSettings() }
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
        coEvery { settingsSyncEngine.syncSettings() } returns
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
        coEvery { taskDao.getTaskById(any()) } returns null

        val serverSession = PomodoroSessionDto(
            id = "server-session-1",
            startedAt = "2025-01-01T00:00:00Z",
            endedAt = "2025-01-01T00:25:00Z",
            mode = "pomodoro",
            phase = "work",
            durationSeconds = 1500,
            createdAt = "2025-01-01T00:00:00Z",
        )
        coEvery { apiClient.syncSessions(any()) } returns NetworkResult.Success(
            SessionSyncResponse(
                sessions = listOf(serverSession),
                serverTimestamp = "2025-06-15T12:00:00Z",
            )
        )

        syncEngine.syncSessions()

        // Verify sessions were upserted
        coVerify { sessionDao.upsertSessions(any()) }
        // Verify dirty sessions were marked synced
        coVerify { sessionDao.markSynced("session-1", any()) }
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
    // B-C8: mergeServerTasks — last-writer-wins conflict resolution (4 branches).
    // Driven through syncTasks() -> pullAllTasks() (dirty list empty).
    // -----------------------------------------------------------------------

    private fun serverTaskDto(
        serverId: Int = 10,
        syncId: String = "local-1",
        updatedAt: String = "2025-06-18T12:00:00Z",
        title: String = "From server",
    ) = TaskDto(id = serverId, syncId = syncId, updatedAt = updatedAt, title = title)

    @Test
    fun `B-C8 branch1 - local null inserts server task`() = runTest {
        coEvery { taskDao.getDirtyTasks() } returns emptyList()
        coEvery { taskDao.getTaskById("local-1") } returns null
        coEvery { taskDao.getTaskByServerId(10) } returns null
        coEvery { apiClient.getTasks() } returns NetworkResult.Success(listOf(serverTaskDto()))

        syncEngine.syncTasks()

        coVerify { taskDao.insertTask(any()) }
        coVerify(exactly = 0) { taskDao.updateTask(any()) }
    }

    @Test
    fun `B-C8 branch2 - local not dirty is always replaced by server`() = runTest {
        val local = TaskEntity(
            id = "local-1",
            title = "Local mirror",
            createdAt = 1_000L,
            updatedAt = 9_999_999_999_999L, // far future → server is "older"
            isDirty = false,
        )
        coEvery { taskDao.getDirtyTasks() } returns emptyList()
        coEvery { taskDao.getTaskById("local-1") } returns local
        coEvery { apiClient.getTasks() } returns NetworkResult.Success(listOf(serverTaskDto()))

        syncEngine.syncTasks()

        coVerify { taskDao.updateTask(any()) }
        coVerify(exactly = 0) { taskDao.insertTask(any()) }
    }

    @Test
    fun `B-C8 branch3 - dirty local overridden when server is newer`() = runTest {
        val local = TaskEntity(
            id = "local-1",
            title = "Stale dirty local",
            createdAt = 1_000L,
            updatedAt = 1_000L, // very old
            isDirty = true,
        )
        coEvery { taskDao.getDirtyTasks() } returns emptyList()
        coEvery { taskDao.getTaskById("local-1") } returns local
        // Server updatedAt (2025-06-18) parses to ~1.75e12 >> local.updatedAt (1000).
        coEvery { apiClient.getTasks() } returns NetworkResult.Success(listOf(serverTaskDto()))

        syncEngine.syncTasks()

        coVerify { taskDao.updateTask(any()) }
    }

    @Test
    fun `B-C8 branch4 - dirty local kept when server is not newer`() = runTest {
        val local = TaskEntity(
            id = "local-1",
            title = "Fresh dirty local",
            createdAt = 1_000L,
            updatedAt = 9_999_999_999_999L, // far future, newer than server
            isDirty = true,
        )
        coEvery { taskDao.getDirtyTasks() } returns emptyList()
        coEvery { taskDao.getTaskById("local-1") } returns local
        coEvery { apiClient.getTasks() } returns NetworkResult.Success(listOf(serverTaskDto()))

        syncEngine.syncTasks()

        coVerify(exactly = 0) { taskDao.updateTask(any()) }
        coVerify(exactly = 0) { taskDao.insertTask(any()) }
    }

    // -----------------------------------------------------------------------
    // B-C9: mergeServerStats — compare by updatedAt + dirty flag for re-push.
    // Driven through syncDailyStats() (push first, then pull+merge).
    // -----------------------------------------------------------------------

    private fun statsDto(
        date: String = "2025-06-18",
        count: Int = 3,
        updatedAt: String = "2025-06-18T12:00:00Z",
    ) = FocusStatsDto(date = date, count = count, updatedAt = updatedAt)

    @Test
    fun `B-C9 push phase uploads dirty stats and clears dirty flag`() = runTest {
        val dirty = DailyStatsEntity(
            date = 1L,
            sessionsCompleted = 5,
            isDirty = true,
            syncedAt = null,
        )
        every { dailyStatsDao.getAllDaysWithSessions() } returns flowOf(listOf(dirty))
        coEvery { apiClient.upsertStats(any()) } returns
            NetworkResult.Success(FocusStatsDto(date = "2025-06-18", count = 5))
        coEvery { apiClient.getStats(any(), any()) } returns NetworkResult.Success(emptyList())
        coEvery { dailyStatsDao.getStatsForDate(any()) } returns null

        syncEngine.syncDailyStats()

        coVerify { apiClient.upsertStats(any()) }
        coVerify { dailyStatsDao.upsert(match { !it.isDirty && it.sessionsCompleted == 5 && it.syncedAt != null }) }
    }

    @Test
    fun `B-C9 dirty local preserved when server has lower count`() = runTest {
        val existing = DailyStatsEntity(
            date = 1L,
            sessionsCompleted = 5,
            isDirty = true,
            syncedAt = 1_000L,
        )
        every { dailyStatsDao.getAllDaysWithSessions() } returns flowOf(emptyList())
        coEvery { apiClient.getStats(any(), any()) } returns
            NetworkResult.Success(listOf(statsDto(count = 3)))
        coEvery { dailyStatsDao.getStatsForDate(any()) } returns existing

        syncEngine.syncDailyStats()

        coVerify(exactly = 0) { dailyStatsDao.upsert(match { it.sessionsCompleted == 3 }) }
    }

    @Test
    fun `B-C9 non-dirty local higher than older server flagged dirty for re-push`() = runTest {
        val existing = DailyStatsEntity(
            date = 1L,
            sessionsCompleted = 5,
            isDirty = false,
            syncedAt = 9_999_999_999_999L, // far future → server updatedAt is NOT newer
        )
        every { dailyStatsDao.getAllDaysWithSessions() } returns flowOf(emptyList())
        coEvery { apiClient.getStats(any(), any()) } returns
            NetworkResult.Success(listOf(statsDto(count = 3)))
        coEvery { dailyStatsDao.getStatsForDate(any()) } returns existing

        syncEngine.syncDailyStats()

        coVerify { dailyStatsDao.upsert(match { it.isDirty && it.sessionsCompleted == 5 }) }
    }

    @Test
    fun `B-C9 server newer replaces non-dirty local`() = runTest {
        val existing = DailyStatsEntity(
            date = 1L,
            sessionsCompleted = 2,
            isDirty = false,
            syncedAt = 1_000L, // server (2025 epoch) is newer
        )
        every { dailyStatsDao.getAllDaysWithSessions() } returns flowOf(emptyList())
        coEvery { apiClient.getStats(any(), any()) } returns
            NetworkResult.Success(listOf(statsDto(count = 3)))
        coEvery { dailyStatsDao.getStatsForDate(any()) } returns existing

        syncEngine.syncDailyStats()

        coVerify { dailyStatsDao.upsert(match { !it.isDirty && it.sessionsCompleted == 3 }) }
    }
}
