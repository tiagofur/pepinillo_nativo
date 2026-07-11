package dev.creapolis.pepinillo.data.sync

import dev.creapolis.pepinillo.core.network.FullSyncResponse
import dev.creapolis.pepinillo.core.network.NetworkResult
import dev.creapolis.pepinillo.core.network.PaginatedSessionPage
import dev.creapolis.pepinillo.core.network.PaginatedTaskPage
import dev.creapolis.pepinillo.core.network.PepinilloApiClient
import dev.creapolis.pepinillo.core.network.PomodoroSessionDto
import dev.creapolis.pepinillo.core.network.TaskDto
import dev.creapolis.pepinillo.data.local.PepinilloDatabase
import dev.creapolis.pepinillo.data.local.dao.FocusSessionDao
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
    private lateinit var database: PepinilloDatabase
    private lateinit var taskDao: TaskDao
    private lateinit var sessionDao: FocusSessionDao
    private lateinit var settingsSyncEngine: SettingsSyncEngine
    private lateinit var syncMetadataStore: SyncMetadataStore
    private lateinit var manager: InitialSyncManager

    @Before
    fun setUp() {
        apiClient = mockk(relaxed = true)
        database = mockk(relaxed = true)
        taskDao = mockk(relaxed = true)
        sessionDao = mockk(relaxed = true)
        settingsSyncEngine = mockk(relaxed = true)
        syncMetadataStore = mockk(relaxed = true)

        manager = InitialSyncManager(
            apiClient = apiClient,
            database = database,
            taskDao = taskDao,
            sessionDao = sessionDao,
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
        tasks = PaginatedTaskPage(items = tasks, nextCursor = taskNextCursor, hasMore = taskNextCursor != null),
        sessions = PaginatedSessionPage(items = emptyList(), nextCursor = sessionNextCursor, hasMore = sessionNextCursor != null),
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

        coEvery {
            apiClient.getFullSync(taskCursor = null, sessionCursor = null, limit = 100)
        } returns NetworkResult.Success(
            fullSyncResponse(tasks = listOf(task1), taskNextCursor = "cursor-page-2")
        )

        coEvery {
            apiClient.getFullSync(taskCursor = "cursor-page-2", sessionCursor = any(), limit = 100)
        } returns NetworkResult.Success(
            fullSyncResponse(tasks = listOf(task2), taskNextCursor = null)
        )

        val result = manager.performInitialSync()
        assertEquals(InitialSyncManager.InitialSyncResult.Success, result)

        // Both pages accumulated, then applied in a single transactional snapshot
        coVerify(exactly = 1) {
            database.replaceSyncSnapshot(
                tasks = match { it.size == 2 },
                subtasks = any(),
                sessions = any(),
            )
        }
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

        coVerify(exactly = 1) {
            database.replaceSyncSnapshot(
                tasks = emptyList(),
                subtasks = emptyList(),
                sessions = emptyList(),
            )
        }
    }

    // -----------------------------------------------------------------------
    // performInitialSync -- stores serverTimestamp and initialPullComplete
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
        verify { syncMetadataStore.initialPullComplete = true }
    }

    // -----------------------------------------------------------------------
    // performInitialSync -- fetch failure writes nothing
    // -----------------------------------------------------------------------

    @Test
    fun `performInitialSync fetch failure writes nothing`() = runTest {
        coEvery {
            apiClient.getFullSync(any(), any(), any())
        } returns NetworkResult.NetworkError(RuntimeException("timeout"))

        val result = manager.performInitialSync()

        assertTrue(result is InitialSyncManager.InitialSyncResult.Error)
        coVerify(exactly = 0) { database.replaceSyncSnapshot(any(), any(), any()) }
        verify(exactly = 0) { syncMetadataStore.initialPullComplete = true }
    }

    // -----------------------------------------------------------------------
    // wipeAndSync -- uses transactional apply after successful download
    // -----------------------------------------------------------------------

    @Test
    fun `wipeAndSync applies snapshot transactionally after successful download`() = runTest {
        coEvery {
            apiClient.getFullSync(taskCursor = null, sessionCursor = null, limit = 100)
        } returns NetworkResult.Success(fullSyncResponse())

        val result = manager.wipeAndSync()
        assertEquals(InitialSyncManager.InitialSyncResult.Success, result)

        coVerify(exactly = 1) {
            database.replaceSyncSnapshot(any(), any(), any())
        }
        verify { syncMetadataStore.initialPullComplete = true }
    }

    @Test
    fun `wipeAndSync fetches all server pages before applying snapshot`() = runTest {
        coEvery {
            apiClient.getFullSync(taskCursor = null, sessionCursor = null, limit = 100)
        } returns NetworkResult.Success(fullSyncResponse())

        manager.wipeAndSync()

        coVerifyOrder {
            apiClient.getFullSync(any(), any(), any())
            database.replaceSyncSnapshot(any(), any(), any())
        }
    }

    // -----------------------------------------------------------------------
    // wipeAndSync -- network failure during download leaves local data intact
    // -----------------------------------------------------------------------

    @Test
    fun `wipeAndSync network failure leaves local data intact`() = runTest {
        coEvery {
            apiClient.getFullSync(any(), any(), any())
        } returns NetworkResult.NetworkError(RuntimeException("timeout"))

        val result = manager.wipeAndSync()

        assertTrue(result is InitialSyncManager.InitialSyncResult.Error)
        coVerify(exactly = 0) { database.replaceSyncSnapshot(any(), any(), any()) }
        verify(exactly = 0) { syncMetadataStore.initialPullComplete = true }
    }

    @Test
    fun `wipeAndSync server error during download leaves local data intact`() = runTest {
        coEvery {
            apiClient.getFullSync(any(), any(), any())
        } returns NetworkResult.Error(500, "Internal Server Error")

        val result = manager.wipeAndSync()

        assertTrue(result is InitialSyncManager.InitialSyncResult.Error)
        coVerify(exactly = 0) { database.replaceSyncSnapshot(any(), any(), any()) }
    }

    // -----------------------------------------------------------------------
    // Asymmetric pagination -- tasks finish before sessions; no task duplicates
    // -----------------------------------------------------------------------

    @Test
    fun `asymmetric pagination tasks finish on page 1 sessions need more pages no duplicate task upserts`() = runTest {
        val task1 = TaskDto(id = 1, syncId = "t-1", title = "Task 1", updatedAt = "2025-01-01T00:00:00Z")
        val session1 = PomodoroSessionDto(id = "s-1", startedAt = "2025-01-01T00:00:00Z", createdAt = "2025-01-01T00:00:00Z", updatedAt = "2025-01-01T00:00:00Z")
        val session2 = PomodoroSessionDto(id = "s-2", startedAt = "2025-01-02T00:00:00Z", createdAt = "2025-01-02T00:00:00Z", updatedAt = "2025-01-02T00:00:00Z")

        coEvery {
            apiClient.getFullSync(taskCursor = null, sessionCursor = null, limit = 100)
        } returns NetworkResult.Success(
            FullSyncResponse(
                tasks = PaginatedTaskPage(items = listOf(task1), nextCursor = null, hasMore = false),
                sessions = PaginatedSessionPage(items = listOf(session1), nextCursor = "session-cursor-2", hasMore = true),
                settings = emptyList(),
                serverTimestamp = "2025-01-01T00:00:00Z",
            )
        )

        coEvery {
            apiClient.getFullSync(taskCursor = null, sessionCursor = "session-cursor-2", limit = 100)
        } returns NetworkResult.Success(
            FullSyncResponse(
                tasks = PaginatedTaskPage(items = listOf(task1), nextCursor = null, hasMore = false),
                sessions = PaginatedSessionPage(items = listOf(session2), nextCursor = null, hasMore = false),
                settings = emptyList(),
                serverTimestamp = "2025-01-02T00:00:00Z",
            )
        )

        val result = manager.performInitialSync()
        assertEquals(InitialSyncManager.InitialSyncResult.Success, result)

        // Tasks accumulated exactly once across both pages (page 2 task items skipped)
        coVerify(exactly = 1) {
            database.replaceSyncSnapshot(
                tasks = match { it.size == 1 },
                subtasks = any(),
                sessions = match { it.size == 2 },
            )
        }
    }

    @Test
    fun `wipeAndSync asymmetric pagination accumulates tasks exactly once`() = runTest {
        val task1 = TaskDto(id = 1, syncId = "t-1", title = "Task 1", updatedAt = "2025-01-01T00:00:00Z")
        val session1 = PomodoroSessionDto(id = "s-1", startedAt = "2025-01-01T00:00:00Z", createdAt = "2025-01-01T00:00:00Z", updatedAt = "2025-01-01T00:00:00Z")
        val session2 = PomodoroSessionDto(id = "s-2", startedAt = "2025-01-02T00:00:00Z", createdAt = "2025-01-02T00:00:00Z", updatedAt = "2025-01-02T00:00:00Z")

        coEvery {
            apiClient.getFullSync(taskCursor = null, sessionCursor = null, limit = 100)
        } returns NetworkResult.Success(
            FullSyncResponse(
                tasks = PaginatedTaskPage(items = listOf(task1), nextCursor = null, hasMore = false),
                sessions = PaginatedSessionPage(items = listOf(session1), nextCursor = "session-cursor-2", hasMore = true),
                settings = emptyList(),
                serverTimestamp = "2025-01-01T00:00:00Z",
            )
        )

        coEvery {
            apiClient.getFullSync(taskCursor = null, sessionCursor = "session-cursor-2", limit = 100)
        } returns NetworkResult.Success(
            FullSyncResponse(
                tasks = PaginatedTaskPage(items = listOf(task1), nextCursor = null, hasMore = false),
                sessions = PaginatedSessionPage(items = listOf(session2), nextCursor = null, hasMore = false),
                settings = emptyList(),
                serverTimestamp = "2025-01-02T00:00:00Z",
            )
        )

        manager.wipeAndSync()

        coVerify(exactly = 1) {
            database.replaceSyncSnapshot(
                tasks = match { it.size == 1 },
                subtasks = any(),
                sessions = match { it.size == 2 },
            )
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
        coVerify(exactly = 0) { database.replaceSyncSnapshot(any(), any(), any()) }
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
        coVerify(exactly = 0) { database.replaceSyncSnapshot(any(), any(), any()) }
    }
}