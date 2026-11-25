package dev.creapolis.pepinillo.data.sync

import dev.creapolis.pepinillo.core.auth.AuthStore
import dev.creapolis.pepinillo.core.network.FullSyncResponse
import dev.creapolis.pepinillo.core.network.PaginatedSessionPage
import dev.creapolis.pepinillo.core.network.PaginatedTaskPage
import dev.creapolis.pepinillo.core.billing.SubscriptionManager
import dev.creapolis.pepinillo.core.billing.SubscriptionState
import dev.creapolis.pepinillo.core.billing.SubscriptionTier
import dev.creapolis.pepinillo.core.network.NetworkResult
import dev.creapolis.pepinillo.core.network.PepinilloApiClient
import dev.creapolis.pepinillo.core.network.TaskDto
import dev.creapolis.pepinillo.core.network.TaskSyncRequest
import dev.creapolis.pepinillo.core.network.TaskSyncResponse
import dev.creapolis.pepinillo.data.local.PepinilloDatabase
import dev.creapolis.pepinillo.data.local.dao.DailyStatsDao
import dev.creapolis.pepinillo.data.local.dao.FocusSessionDao
import dev.creapolis.pepinillo.data.local.dao.PreferenceSyncDao
import dev.creapolis.pepinillo.data.local.dao.SubtaskDao
import dev.creapolis.pepinillo.data.local.dao.TaskDao
import dev.creapolis.pepinillo.data.local.entity.TaskEntity
import dev.creapolis.pepinillo.data.local.preferences.UserPreferences
import dev.creapolis.pepinillo.data.local.preferences.UserPreferencesRepository
import io.mockk.coEvery
import io.mockk.coVerify
import io.mockk.mockk
import io.mockk.slot
import io.mockk.every
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import java.util.Calendar
import java.util.TimeZone

/**
 * Issue #989 PR-B (S5): the task sync wire carries the canonical task-model
 * fields. Android stops overloading finishDate (it used to carry completedAt)
 * and speaks the canonical energy vocabulary; the pull merge applies the
 * server's due/today/order/completed fields full-row now that the backend
 * persists them.
 */
class TaskCanonicalFieldsSyncTest {

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
    private lateinit var context: android.content.Context
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
        every { authStore.getAccessToken() } returns "valid-token"
        every { subscriptionManager.subscriptionState } returns MutableStateFlow(
            SubscriptionState(tier = SubscriptionTier.EVERYWHERE_MONTHLY),
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

    private fun rfc3339Utc(year: Int, month: Int, day: Int, hour: Int = 12): String =
        Calendar.getInstance(TimeZone.getTimeZone("UTC")).run {
            clear()
            set(year, month - 1, day, hour, 0, 0)
            SyncDateUtils.run { timeInMillis.toRfc3339() }
        }

    // S5 upload: Android speaks canonical energy and stops stuffing completedAt
    // into the legacy finishDate carrier.
    @Test
    fun `upload sends canonical energy and completedAt and omits finishDate`() = runTest {
        val due = Calendar.getInstance(TimeZone.getTimeZone("UTC")).apply {
            clear(); set(2026, 10, 27, 9, 0, 0)
        }.timeInMillis
        val completed = Calendar.getInstance(TimeZone.getTimeZone("UTC")).apply {
            clear(); set(2026, 10, 25, 15, 30, 0)
        }.timeInMillis
        val tasks = listOf(
            TaskEntity(
                id = "t-deep", title = "Deep", createdAt = 1000L, updatedAt = 2000L,
                isDirty = true, energyLevel = "Deep", dueDate = due,
                completedAt = completed, scheduledForToday = true,
            ),
            TaskEntity(
                id = "t-light", title = "Light", createdAt = 1000L, updatedAt = 2000L,
                isDirty = true, energyLevel = "Light",
            ),
            TaskEntity(
                id = "t-regular", title = "Regular", createdAt = 1000L, updatedAt = 2000L,
                isDirty = true, energyLevel = "Regular",
            ),
        )
        coEvery { taskDao.getDirtyTasks() } returns tasks
        coEvery { subtaskDao.getSubtasksForTaskSync(any()) } returns emptyList()
        val requestSlot = slot<TaskSyncRequest>()
        coEvery { apiClient.syncTasks(capture(requestSlot)) } returns NetworkResult.Success(
            TaskSyncResponse(tasks = emptyList()),
        )

        syncEngine.syncTasks()

        val dtos = requestSlot.captured.tasks.associateBy { it.syncId }
        val deep = dtos.getValue("t-deep")
        assertEquals("deep", deep.energyLevel)
        assertNotNull("dueDate must ride the canonical field", deep.dueDate)
        assertNotNull("completedAt must ride the canonical field", deep.completedAt)
        assertEquals(completed, deep.completedAt!!.let { SyncDateUtils.parseRfc3339(it) })
        assertTrue("Add to Today must travel", deep.scheduledForToday)
        assertNull("finishDate must be retired by Android uploads", deep.finishDate)

        assertEquals("shallow", dtos.getValue("t-light").energyLevel)
        assertEquals("admin", dtos.getValue("t-regular").energyLevel)
    }

    // S5 pull/merge: the server now persists the canonical fields, so the
    // full-row merge applies them without the pre-PR-A guards (server truth
    // wins for due/today/order/completed; energy maps onto Android labels).
    @Test
    fun `pull merge applies server due today order completed full-row`() = runTest {
        val local = TaskEntity(
            id = "task-1", title = "Local", createdAt = 1000L, updatedAt = 1000L,
            isDirty = false, serverId = 10,
            scheduledForToday = false, sortOrder = 0, completedAt = null,
        )
        val due = Calendar.getInstance(TimeZone.getTimeZone("UTC")).apply {
            clear(); set(2026, 10, 20, 9, 0, 0)
        }.timeInMillis
        val completed = Calendar.getInstance(TimeZone.getTimeZone("UTC")).apply {
            clear(); set(2026, 10, 24, 18, 0, 0)
        }.timeInMillis
        coEvery { taskDao.getDirtyTasks() } returns emptyList()
        coEvery { taskDao.getTaskByServerId(10) } returns local
        coEvery { apiClient.syncTasks(any()) } returns NetworkResult.Success(
            TaskSyncResponse(tasks = emptyList()),
        )
        // The authoritative merge is fed by the full pull, not the push ack.
        coEvery { apiClient.getTasks() } returns NetworkResult.Success(
            listOf(
                TaskDto(
                    id = 10, syncId = "task-1", title = "Server", updatedAt = rfc3339Utc(2026, 11, 25, 8),
                    dueDate = rfc3339Utc(2026, 11, 20, 9),
                    completedAt = rfc3339Utc(2026, 11, 24, 18),
                    scheduledForToday = true, sortOrder = 7, energyLevel = "shallow",
                    // legacy carrier present but must NOT be read as completion
                    finishDate = rfc3339Utc(2026, 11, 20, 9),
                ),
            ),
        )

        syncEngine.syncTasks()

        val mergedSlot = slot<TaskEntity>()
        coVerify { taskDao.updateTask(capture(mergedSlot)) }
        val merged = mergedSlot.captured
        assertEquals("server dueDate must survive the merge", due, merged.dueDate)
        assertEquals("server today-pin must apply full-row", true, merged.scheduledForToday)
        assertEquals("server drag order must apply full-row", 7, merged.sortOrder)
        assertEquals("completedAt must come from the canonical field", completed, merged.completedAt)
        assertEquals("canonical energy maps onto the Android label", "Light", merged.energyLevel)
    }

    // S5: a stale server pin (server newer, says false) clears the local pin —
    // full-row semantics, no silent resurrection.
    @Test
    fun `pull merge clears local today-pin when newer server says false`() = runTest {
        val local = TaskEntity(
            id = "task-2", title = "Pinned", createdAt = 1000L, updatedAt = 1000L,
            isDirty = false, serverId = 11, scheduledForToday = true,
        )
        coEvery { taskDao.getDirtyTasks() } returns emptyList()
        coEvery { taskDao.getTaskByServerId(11) } returns local
        coEvery { apiClient.syncTasks(any()) } returns NetworkResult.Success(
            TaskSyncResponse(tasks = emptyList()),
        )
        coEvery { apiClient.getTasks() } returns NetworkResult.Success(
            listOf(
                TaskDto(
                    id = 11, syncId = "task-2", title = "Pinned", updatedAt = rfc3339Utc(2026, 11, 25, 8),
                    scheduledForToday = false, sortOrder = 3,
                ),
            ),
        )

        syncEngine.syncTasks()

        val mergedSlot = slot<TaskEntity>()
        coVerify { taskDao.updateTask(capture(mergedSlot)) }
        assertEquals(false, mergedSlot.captured.scheduledForToday)
        assertEquals(3, mergedSlot.captured.sortOrder)
    }

// S5 (judge A round 1): InitialSyncManager mirrors the same canonical mapping
// for the initial restore — reverting it must fail too, not just SyncEngine.
@Test
fun `initial restore maps canonical energy completedAt and fields`() = runTest {
    val restoreApi = mockk<PepinilloApiClient>(relaxed = true)
    val restoreDb = mockk<PepinilloDatabase>(relaxed = true)
    val restoreTaskDao = mockk<TaskDao>(relaxed = true)
    val restoreSessionDao = mockk<FocusSessionDao>(relaxed = true)
    val restoreSettings = mockk<SettingsSyncEngine>(relaxed = true)
    val restoreMetadata = mockk<SyncMetadataStore>(relaxed = true)
    val restore = InitialSyncManager(
        apiClient = restoreApi,
        database = restoreDb,
        taskDao = restoreTaskDao,
        sessionDao = restoreSessionDao,
        settingsSyncEngine = restoreSettings,
        syncMetadataStore = restoreMetadata,
    )
    val completed = Calendar.getInstance(TimeZone.getTimeZone("UTC")).apply {
        clear(); set(2026, 10, 24, 18, 0, 0)
    }.timeInMillis
    coEvery {
        restoreApi.getFullSync(taskCursor = null, sessionCursor = null, limit = 100)
    } returns NetworkResult.Success(
        FullSyncResponse(
            tasks = PaginatedTaskPage(
                items = listOf(
                    TaskDto(
                        id = 1, syncId = "t-restore", title = "Canonical", updatedAt = rfc3339Utc(2026, 11, 25, 8),
                        dueDate = rfc3339Utc(2026, 11, 20, 9),
                        completedAt = rfc3339Utc(2026, 11, 24, 18),
                        scheduledForToday = true, sortOrder = 5, energyLevel = "admin",
                        // legacy decoy: must NOT be read as the completion instant
                        finishDate = rfc3339Utc(2026, 11, 20, 9),
                    ),
                ),
                nextCursor = null, hasMore = false,
            ),
            sessions = PaginatedSessionPage(items = emptyList(), nextCursor = null, hasMore = false),
            settings = emptyList(),
            serverTimestamp = rfc3339Utc(2026, 11, 25, 8),
        ),
    )

    val result = restore.performInitialSync()
    assertEquals(InitialSyncManager.InitialSyncResult.Success, result)

    val tasksSlot = slot<List<TaskEntity>>()
    coVerify { restoreDb.replaceSyncSnapshot(tasks = capture(tasksSlot), subtasks = any(), sessions = any()) }
    val mapped = tasksSlot.captured.single()
    assertEquals("admin maps onto the Android Regular label", "Regular", mapped.energyLevel)
    assertEquals("completedAt must come from the canonical field, not the decoy", completed, mapped.completedAt)
    assertEquals("restore applies the server today-pin", true, mapped.scheduledForToday)
    assertEquals("restore applies the server drag order", 5, mapped.sortOrder)
    assertNotNull("restore keeps the server due date", mapped.dueDate)
}

}
