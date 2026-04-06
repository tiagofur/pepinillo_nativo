package dev.creapolis.pepinillo.data.sync

import dev.creapolis.pepinillo.core.network.FullSyncResponse
import dev.creapolis.pepinillo.core.network.NetworkResult
import dev.creapolis.pepinillo.core.network.PaginatedSessionPage
import dev.creapolis.pepinillo.core.network.PaginatedTaskPage
import dev.creapolis.pepinillo.core.network.PepinilloApiClient
import dev.creapolis.pepinillo.core.network.TaskDto
import dev.creapolis.pepinillo.data.local.dao.DailyStatsDao
import dev.creapolis.pepinillo.data.local.dao.FocusSessionDao
import dev.creapolis.pepinillo.data.local.dao.PreferenceSyncDao
import dev.creapolis.pepinillo.data.local.dao.SubtaskDao
import dev.creapolis.pepinillo.data.local.dao.TaskDao
import io.mockk.coEvery
import io.mockk.coVerify
import io.mockk.coVerifyOrder
import io.mockk.mockk
import io.mockk.verify
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

class InitialSyncManagerTest {

    private lateinit var apiClient: PepinilloApiClient
    private lateinit var taskDao: TaskDao
    private lateinit var subtaskDao: SubtaskDao
    private lateinit var sessionDao: FocusSessionDao
    private lateinit var dailyStatsDao: DailyStatsDao
    private lateinit var preferenceSyncDao: PreferenceSyncDao
    private lateinit var settingsSyncEngine: SettingsSyncEngine
    private lateinit var syncMetadataStore: SyncMetadataStore
    private lateinit var manager: InitialSyncManager

    @Before
    fun setUp() {
        apiClient = mockk(relaxed = true)
        taskDao = mockk(relaxed = true)
        subtaskDao = mockk(relaxed = true)
        sessionDao = mockk(relaxed = true)
        dailyStatsDao = mockk(relaxed = true)
        preferenceSyncDao = mockk(relaxed = true)
        settingsSyncEngine = mockk(relaxed = true)
        syncMetadataStore = mockk(relaxed = true)

        manager = InitialSyncManager(
            apiClient = apiClient,
            taskDao = taskDao,
            subtaskDao = subtaskDao,
            sessionDao = sessionDao,
            dailyStatsDao = dailyStatsDao,
            preferenceSyncDao = preferenceSyncDao,
            settingsSyncEngine = settingsSyncEngine,
            syncMetadataStore = syncMetadataStore,
        )
    }

    // -----------------------------------------------------------------------
    // Helper: create a FullSyncResponse
    // -----------------------------------------------------------------------

    private fun fullSyncResponse(
        tasks: List<TaskDto> = emptyList(),
        taskNextCursor: String? = null,
        sessionNextCursor: String? = null,
        serverTimestamp: String = "2025-01-01T00:00:00Z",
    ) = FullSyncResponse(
        tasks = PaginatedTaskPage(items = tasks, nextCursor = taskNextCursor),
        sessions = PaginatedSessionPage(items = emptyList(), nextCursor = sessionNextCursor),
        settings = emptyList(),
        serverTimestamp = serverTimestamp,
    )

    // -----------------------------------------------------------------------
    // performInitialSync -- paginates through all tasks
    // -----------------------------------------------------------------------

    @Test
    fun `performInitialSync paginates through all tasks`() = runTest {
        val task1 = TaskDto(id = 1, syncId = "t-1", title = "Task 1", updatedAt = "2025-01-01T00:00:00Z")
        val task2 = TaskDto(id = 2, syncId = "t-2", title = "Task 2", updatedAt = "2025-01-02T00:00:00Z")

        // First page: 1 task with cursor
        coEvery {
            apiClient.getFullSync(taskCursor = null, sessionCursor = null, limit = 100)
        } returns NetworkResult.Success(
            fullSyncResponse(tasks = listOf(task1), taskNextCursor = "cursor-page-2")
        )

        // Second page: 1 task, no more cursor
        coEvery {
            apiClient.getFullSync(taskCursor = "cursor-page-2", sessionCursor = any(), limit = 100)
        } returns NetworkResult.Success(
            fullSyncResponse(tasks = listOf(task2), taskNextCursor = null)
        )

        val result = manager.performInitialSync()
        assertEquals(InitialSyncManager.InitialSyncResult.Success, result)

        // Verify both pages of tasks were upserted
        coVerify(exactly = 2) { taskDao.upsertAll(any()) }
    }

    // -----------------------------------------------------------------------
    // performInitialSync -- handles empty response
    // -----------------------------------------------------------------------

    @Test
    fun `performInitialSync handles empty response`() = runTest {
        coEvery {
            apiClient.getFullSync(taskCursor = null, sessionCursor = null, limit = 100)
        } returns NetworkResult.Success(fullSyncResponse())

        val result = manager.performInitialSync()
        assertEquals(InitialSyncManager.InitialSyncResult.Success, result)

        // No tasks to upsert
        coVerify(exactly = 0) { taskDao.upsertAll(any()) }
    }

    // -----------------------------------------------------------------------
    // performInitialSync -- stores serverTimestamp
    // -----------------------------------------------------------------------

    @Test
    fun `performInitialSync stores serverTimestamp`() = runTest {
        coEvery {
            apiClient.getFullSync(taskCursor = null, sessionCursor = null, limit = 100)
        } returns NetworkResult.Success(
            fullSyncResponse(serverTimestamp = "2025-06-15T12:00:00Z")
        )

        manager.performInitialSync()

        verify { syncMetadataStore.lastSessionSyncAt = "2025-06-15T12:00:00Z" }
    }

    // -----------------------------------------------------------------------
    // wipeAndSync -- clears all tables before syncing
    // -----------------------------------------------------------------------

    @Test
    fun `wipeAndSync clears all tables before syncing`() = runTest {
        coEvery {
            apiClient.getFullSync(taskCursor = null, sessionCursor = null, limit = 100)
        } returns NetworkResult.Success(fullSyncResponse())

        val result = manager.wipeAndSync()
        assertEquals(InitialSyncManager.InitialSyncResult.Success, result)

        coVerify { taskDao.deleteAll() }
        coVerify { subtaskDao.deleteAll() }
        coVerify { sessionDao.deleteAll() }
        coVerify { dailyStatsDao.deleteAll() }
        coVerify { preferenceSyncDao.deleteAll() }
    }

    // -----------------------------------------------------------------------
    // wipeAndSync -- calls performInitialSync after wipe
    // -----------------------------------------------------------------------

    @Test
    fun `wipeAndSync calls performInitialSync after wipe`() = runTest {
        coEvery {
            apiClient.getFullSync(taskCursor = null, sessionCursor = null, limit = 100)
        } returns NetworkResult.Success(fullSyncResponse())

        manager.wipeAndSync()

        // Verify wipe happens before sync (deleteAll before getFullSync)
        coVerifyOrder {
            taskDao.deleteAll()
            apiClient.getFullSync(any(), any(), any())
        }
    }

    // -----------------------------------------------------------------------
    // returns NotAuthenticated on 401
    // -----------------------------------------------------------------------

    @Test
    fun `returns NotAuthenticated on 401`() = runTest {
        coEvery {
            apiClient.getFullSync(taskCursor = null, sessionCursor = null, limit = 100)
        } returns NetworkResult.Error(401, "Unauthorized")

        val result = manager.performInitialSync()
        assertEquals(InitialSyncManager.InitialSyncResult.NotAuthenticated, result)
    }

    // -----------------------------------------------------------------------
    // returns Error on network failure
    // -----------------------------------------------------------------------

    @Test
    fun `returns Error on network failure`() = runTest {
        coEvery {
            apiClient.getFullSync(taskCursor = null, sessionCursor = null, limit = 100)
        } returns NetworkResult.NetworkError(RuntimeException("No internet"))

        val result = manager.performInitialSync()
        assertTrue(result is InitialSyncManager.InitialSyncResult.Error)
    }
}
