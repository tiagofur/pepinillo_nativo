package dev.creapolis.pepinillo.data.repository

import android.content.Context
import androidx.work.WorkManager
import dagger.hilt.android.qualifiers.ApplicationContext
import dev.creapolis.pepinillo.core.billing.FeatureGate
import dev.creapolis.pepinillo.data.local.dao.FocusSessionDao
import dev.creapolis.pepinillo.data.local.dao.SubtaskDao
import dev.creapolis.pepinillo.data.local.dao.TaskDao
import dev.creapolis.pepinillo.data.local.entity.DailyStatsEntity
import io.mockk.coEvery
import io.mockk.coVerify
import io.mockk.every
import io.mockk.mockk
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.test.runTest
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

        repo = TaskRepository(
            taskDao = taskDao,
            subtaskDao = subtaskDao,
            focusSessionDao = focusSessionDao,
            workManager = workManager,
            sessionRepository = sessionRepository,
            featureGate = featureGate,
            appContext = appContext,
        )
    }

    // ── toggleCompletion: atomic single-statement UPDATE ──────────────────

    @Test
    fun `toggleCompletion delegates to atomic update and skips read-modify-write`() = runTest {
        repo.toggleCompletion("task-1")

        // Must hit the atomic path exactly once. `now` uses a per-call default
        // (System.currentTimeMillis()), so match it with any() to avoid time drift.
        coVerify(exactly = 1) { taskDao.toggleCompletionAtomic("task-1", any()) }
        // Must NOT perform a read-modify-write (the old race-prone pattern).
        coVerify(exactly = 0) { taskDao.getTaskById("task-1") }
        coVerify(exactly = 0) { taskDao.updateTask(any()) }
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
