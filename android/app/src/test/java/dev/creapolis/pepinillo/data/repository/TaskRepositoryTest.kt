package dev.creapolis.pepinillo.data.repository

import android.content.Context
import androidx.work.WorkManager
import dagger.hilt.android.qualifiers.ApplicationContext
import dev.creapolis.pepinillo.core.billing.FeatureGate
import dev.creapolis.pepinillo.data.local.dao.FocusSessionDao
import dev.creapolis.pepinillo.data.local.dao.SubtaskDao
import dev.creapolis.pepinillo.data.local.dao.TaskDao
import dev.creapolis.pepinillo.data.local.entity.DailyStatsEntity
import dev.creapolis.pepinillo.data.local.entity.TaskEntity
import dev.creapolis.pepinillo.feature.tasks.model.RecurrenceOption
import dev.creapolis.pepinillo.feature.tasks.model.Task
import io.mockk.coEvery
import io.mockk.coVerify
import io.mockk.every
import io.mockk.mockk
import io.mockk.slot
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

/**
 * Focused coverage for the atomic transaction / dirty-tracking fixes (Sub-fase 2A-1):
 *
 * - `toggleCompletion` must delegate to the single-statement [TaskDao.toggleCompletionAtomic]
 *   instead of a read-modify-write (which lost updates under concurrency).
 * - `reorderTasks` must delegate to [TaskDao.reorderTasksAtomic] (a `@Transaction` batch)
 *   so a partial failure rolls the whole batch back; the failure surfaces as `Result.failure`.
 * - Subtask mutations must soft-delete / dirty-mark the row AND propagate dirtiness to the
 *   parent task so the next sync push carries the change.
 *
 * Transaction rollback itself is guaranteed by Room's `@Transaction` annotation; these tests
 * pin the repository-layer contract (delegation + failure surfacing + parent-dirty propagation).
 */
class TaskRepositoryTest {

    private lateinit var taskDao: TaskDao
    private lateinit var subtaskDao: SubtaskDao
    private lateinit var focusSessionDao: FocusSessionDao
    private lateinit var workManager: WorkManager
    private lateinit var sessionRepository: SessionRepository
    private lateinit var featureGate: FeatureGate
    private lateinit var appContext: Context
    private lateinit var repo: TaskRepository

    @Before
    fun setUp() {
        taskDao = mockk(relaxed = true)
        subtaskDao = mockk(relaxed = true)
        focusSessionDao = mockk(relaxed = true)
        workManager = mockk(relaxed = true)
        sessionRepository = mockk(relaxed = true)
        featureGate = mockk(relaxed = true)
        appContext = mockk(relaxed = true)

        // refreshWearData() reads these flows on the success path; stub them so the
        // Wear/widget side-effects don't perturb the delegation-under-test.
        every { taskDao.getActiveTasks() } returns flowOf(emptyList())
        every { sessionRepository.getTodayStats() } returns flowOf<DailyStatsEntity?>(null)
        every { sessionRepository.getAllDaysWithSessions() } returns flowOf(emptyList())
        every { featureGate.canUseRecurrence() } returns true

        repo = TaskRepository(
            taskDao = taskDao,
            subtaskDao = subtaskDao,
            focusSessionDao = focusSessionDao,
            workManager = workManager,
            sessionRepository = sessionRepository,
            featureGate = featureGate,
            appContext = appContext,
            appScope = CoroutineScope(kotlinx.coroutines.Dispatchers.Unconfined),
        )
    }

    // ── updateTask: sync metadata must survive domain-field edits ───────────

    @Test
    fun `updateTask preserves completion state from existing row`() = runTest {
        val existing = TaskEntity(
            id = "task-done",
            title = "Done",
            isCompleted = true,
            completedAt = 1_700_000_000_000L,
        )
        val staleEdit = Task(id = "task-done", title = "New title", isCompleted = false)
        val entitySlot = slot<TaskEntity>()

        coEvery { taskDao.getTaskById("task-done") } returns existing
        coEvery { taskDao.updateTask(capture(entitySlot)) } returns Unit

        repo.updateTask(staleEdit)

        assertTrue(entitySlot.captured.isCompleted)
        assertEquals(1_700_000_000_000L, entitySlot.captured.completedAt)
        assertEquals("New title", entitySlot.captured.title)
    }

    @Test
    fun `updateTask preserves serverId syncedAt and isDeleted from existing row`() = runTest {
        val existing = TaskEntity(
            id = "task-synced",
            title = "Old title",
            serverId = 42,
            isDirty = false,
            isDeleted = false,
            syncedAt = 1_700_000_000_000L,
        )
        val updated = Task(id = "task-synced", title = "New title")
        val entitySlot = slot<TaskEntity>()

        coEvery { taskDao.getTaskById("task-synced") } returns existing
        coEvery { taskDao.updateTask(capture(entitySlot)) } returns Unit

        val result = repo.updateTask(updated)

        assertTrue(result.isSuccess)
        assertEquals(42, entitySlot.captured.serverId)
        assertEquals(1_700_000_000_000L, entitySlot.captured.syncedAt)
        assertEquals(false, entitySlot.captured.isDeleted)
        assertEquals(true, entitySlot.captured.isDirty)
        assertEquals("New title", entitySlot.captured.title)
    }

    // ── toggleCompletion: atomic single-statement UPDATE ──────────────────

    @Test
    fun `toggleCompletion delegates to atomic update for non-recurring tasks`() = runTest {
        coEvery { taskDao.getTaskById("task-1") } returns TaskEntity(id = "task-1", title = "Plain")

        repo.toggleCompletion("task-1")

        coVerify(exactly = 1) { taskDao.toggleCompletionAtomic("task-1", any()) }
        coVerify(exactly = 0) { taskDao.updateTask(any()) }
    }

    @Test
    fun `toggleCompletion advances recurring task instead of leaving it completed`() = runTest {
        val today = dev.creapolis.pepinillo.domain.tasks.RecurrenceCalculator.startOfLocalDay()
        val existing = TaskEntity(
            id = "task-recur",
            title = "Daily",
            recurrenceRule = RecurrenceOption.Daily.rrule,
            dueDate = today.timeInMillis,
            isCompleted = false,
        )
        val entitySlot = slot<TaskEntity>()

        coEvery { taskDao.getTaskById("task-recur") } returns existing
        coEvery { taskDao.updateTask(capture(entitySlot)) } returns Unit

        repo.toggleCompletion("task-recur")

        coVerify(exactly = 0) { taskDao.toggleCompletionAtomic(any(), any()) }
        assertEquals(false, entitySlot.captured.isCompleted)
        assertEquals(null, entitySlot.captured.completedAt)
        assertTrue(entitySlot.captured.nextOccurrence != null)
        assertTrue(entitySlot.captured.dueDate!! > today.timeInMillis)
        assertTrue(entitySlot.captured.isRecurringTemplate)
    }

    @Test
    fun `restoreTask uses soft-delete restore without insert replace`() = runTest {
        val task = Task(id = "task-undo", title = "Restored")

        repo.restoreTask(task)

        coVerify(exactly = 1) { taskDao.restoreSoftDelete("task-undo", any()) }
        coVerify(exactly = 0) { taskDao.insertTask(any()) }
    }

    // ── completeTaskFromWear: idempotent complete-only from watch ─────────

    @Test
    fun `completeTaskFromWear delegates to atomic complete for plain tasks`() = runTest {
        coEvery { taskDao.getTaskById("task-1") } returns TaskEntity(id = "task-1", title = "Plain")

        repo.completeTaskFromWear("task-1")

        coVerify(exactly = 1) { taskDao.completeIfIncompleteAtomic("task-1", any()) }
        coVerify(exactly = 0) { taskDao.toggleCompletionAtomic(any(), any()) }
    }

    @Test
    fun `completeTaskFromWear is a no-op when task is already completed`() = runTest {
        coEvery { taskDao.getTaskById("task-done") } returns TaskEntity(
            id = "task-done",
            title = "Done",
            isCompleted = true,
            completedAt = 1_700_000_000_000L,
        )

        repo.completeTaskFromWear("task-done")

        coVerify(exactly = 0) { taskDao.completeIfIncompleteAtomic(any(), any()) }
        coVerify(exactly = 0) { taskDao.toggleCompletionAtomic(any(), any()) }
        coVerify(exactly = 0) { taskDao.updateTask(any()) }
    }

    @Test
    fun `completeTaskFromWear advances recurring task instead of leaving it completed`() = runTest {
        val today = dev.creapolis.pepinillo.domain.tasks.RecurrenceCalculator.startOfLocalDay()
        val existing = TaskEntity(
            id = "task-recur",
            title = "Daily",
            recurrenceRule = RecurrenceOption.Daily.rrule,
            dueDate = today.timeInMillis,
            isCompleted = false,
        )
        val entitySlot = slot<TaskEntity>()

        coEvery { taskDao.getTaskById("task-recur") } returns existing
        coEvery { taskDao.updateTask(capture(entitySlot)) } returns Unit

        repo.completeTaskFromWear("task-recur")

        coVerify(exactly = 0) { taskDao.completeIfIncompleteAtomic(any(), any()) }
        assertEquals(false, entitySlot.captured.isCompleted)
        assertEquals(null, entitySlot.captured.completedAt)
        assertTrue(entitySlot.captured.nextOccurrence != null)
    }

    @Test
    fun `toggleCompletion propagates DAO failure as Result failure`() = runTest {
        coEvery { taskDao.toggleCompletionAtomic(any(), any()) } throws RuntimeException("db locked")

        val result = repo.toggleCompletion("task-1")

        assertTrue(result.isFailure)
    }

    // ── reorderTasks: atomic batch inside a single transaction ────────────

    @Test
    fun `reorderTasks delegates the whole batch to the atomic method`() = runTest {
        val updates = listOf("a" to 0, "b" to 1, "c" to 2)

        repo.reorderTasks(updates)

        // One atomic call carries the whole batch — no per-row window.
        coVerify(exactly = 1) { taskDao.reorderTasksAtomic(updates) }
        coVerify(exactly = 0) { taskDao.updateSortOrder(any(), any(), any()) }
    }

    @Test
    fun `reorderTasks surfaces atomic-batch failure so the rolled-back state is visible`() = runTest {
        // The @Transaction on reorderTasksAtomic guarantees the DB rolled back when this
        // throws; at the repository layer we assert the failure is not swallowed.
        coEvery { taskDao.reorderTasksAtomic(any()) } throws RuntimeException("constraint violation")

        val result = repo.reorderTasks(listOf("a" to 0, "b" to 1))

        assertTrue(result.isFailure)
    }

    @Test
    fun `reorderTasks empty batch is a no-op`() = runTest {
        val result = repo.reorderTasks(emptyList())

        assertTrue(result.isSuccess)
        coVerify(exactly = 0) { taskDao.updateSortOrder(any(), any(), any()) }
    }

    // ── subtask mutations: parent task must be marked dirty ───────────────

    @Test
    fun `addSubtask marks the parent task dirty so the new row syncs`() = runTest {
        repo.addSubtask("task-1", "buy milk")

        coVerify(exactly = 1) { subtaskDao.insertSubtask(any()) }
        coVerify(exactly = 1) { taskDao.markDirty("task-1", any()) }
    }

    @Test
    fun `toggleSubtask toggles the row and marks its parent task dirty`() = runTest {
        coEvery { subtaskDao.getTaskIdForSubtask("sub-1") } returns "task-9"

        repo.toggleSubtask("sub-1")

        coVerify(exactly = 1) { subtaskDao.toggleCompletion("sub-1", any()) }
        coVerify(exactly = 1) { taskDao.markDirty("task-9", any()) }
    }

    @Test
    fun `toggleSubtask survives missing parent lookup without throwing`() = runTest {
        coEvery { subtaskDao.getTaskIdForSubtask("sub-2") } returns null

        val result = repo.toggleSubtask("sub-2")

        assertTrue(result.isSuccess)
        coVerify(exactly = 0) { taskDao.markDirty(any()) }
    }

    @Test
    fun `deleteSubtask uses soft-delete and marks its parent task dirty`() = runTest {
        coEvery { subtaskDao.getTaskIdForSubtask("sub-3") } returns "task-9"

        repo.deleteSubtask("sub-3")

        // Soft-delete (is_deleted=1, is_dirty=1), NOT a hard DELETE.
        coVerify(exactly = 1) { subtaskDao.deleteSubtaskById("sub-3", any()) }
        coVerify(exactly = 0) { subtaskDao.hardDeleteById(any()) }
        coVerify(exactly = 1) { taskDao.markDirty("task-9", any()) }
    }
}
