package dev.creapolis.pepinillo.appfunctions

import dev.creapolis.pepinillo.core.billing.FeatureGate
import dev.creapolis.pepinillo.core.billing.SubscriptionManager
import dev.creapolis.pepinillo.core.billing.SubscriptionState
import dev.creapolis.pepinillo.core.billing.SubscriptionTier
import dev.creapolis.pepinillo.feature.tasks.model.MAX_TASK_TITLE_LENGTH
import dev.creapolis.pepinillo.feature.tasks.model.Task
import dev.creapolis.pepinillo.data.repository.TaskRepository
import io.mockk.coEvery
import io.mockk.coVerify
import io.mockk.every
import io.mockk.mockk
import io.mockk.slot
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Before
import org.junit.Test

/**
 * RED→GREEN tests for the Gemini-facing AppFunction creation logic (issue #912).
 *
 * Uses the real [FeatureGate] (same rule as in-app quick-add, FREE_TASK_LIMIT=3)
 * over a mocked [SubscriptionManager], and a mocked [TaskRepository].
 */
class CreateTaskFunctionTest {

    private lateinit var taskRepository: TaskRepository
    private lateinit var subscriptionManager: SubscriptionManager
    private lateinit var createTaskFunction: CreateTaskFunction

    private fun buildGate(tier: SubscriptionTier) {
        subscriptionManager = mockk(relaxed = true)
        every { subscriptionManager.subscriptionState } returns MutableStateFlow(
            SubscriptionState(tier = tier)
        )
        createTaskFunction = CreateTaskFunction(
            taskRepository = taskRepository,
            featureGate = FeatureGate(subscriptionManager),
        )
    }

    @Before
    fun setUp() {
        taskRepository = mockk(relaxed = true)
        every { taskRepository.getActiveCount() } returns flowOf(0)
        every { taskRepository.getAllTasks() } returns flowOf(emptyList())
        coEvery { taskRepository.addTask(any()) } returns Result.success(Unit)
    }

    // ---------------------------------------------------------------
    // Input normalization
    // ---------------------------------------------------------------

    @Test
    fun `blank title rejected without touching repository`() = runTest {
        buildGate(SubscriptionTier.FREE)

        val result = createTaskFunction.invoke("   ", null)

        assertEquals(CreateTaskFunction.Result.Rejected(CreateTaskFunction.RejectionReason.BLANK_TITLE), result)
        coVerify(exactly = 0) { taskRepository.addTask(any()) }
    }

    @Test
    fun `title is trimmed before persisting`() = runTest {
        buildGate(SubscriptionTier.FREE)

        createTaskFunction.invoke("  Comprar café  ", null)

        coVerify { taskRepository.addTask(match { it.title == "Comprar café" }) }
    }

    @Test
    fun `notes trimmed and blank notes collapse to null`() = runTest {
        buildGate(SubscriptionTier.FREE)

        createTaskFunction.invoke("T1", "  la de avena ")
        createTaskFunction.invoke("T2", "   ")

        coVerify { taskRepository.addTask(match { it.title == "T1" && it.notes == "la de avena" }) }
        coVerify { taskRepository.addTask(match { it.title == "T2" && it.notes == null }) }
    }

    @Test
    fun `title longer than max is truncated (iOS parity)`() = runTest {
        buildGate(SubscriptionTier.FREE)
        val longTitle = "x".repeat(MAX_TASK_TITLE_LENGTH + 50)

        createTaskFunction.invoke(longTitle, null)

        coVerify { taskRepository.addTask(match { it.title.length == MAX_TASK_TITLE_LENGTH }) }
    }

    // ---------------------------------------------------------------
    // Free-tier gate (same rule as in-app quick-add, #216)
    // ---------------------------------------------------------------

    @Test
    fun `free user at limit rejected without persisting`() = runTest {
        buildGate(SubscriptionTier.FREE)
        every { taskRepository.getActiveCount() } returns flowOf(FeatureGate.FREE_TASK_LIMIT)

        val result = createTaskFunction.invoke("Tarea nueva", null)

        assertEquals(CreateTaskFunction.Result.Rejected(CreateTaskFunction.RejectionReason.FREE_TIER_LIMIT), result)
        coVerify(exactly = 0) { taskRepository.addTask(any()) }
    }

    @Test
    fun `free user under limit creates task`() = runTest {
        buildGate(SubscriptionTier.FREE)
        every { taskRepository.getActiveCount() } returns flowOf(FeatureGate.FREE_TASK_LIMIT - 1)

        val result = createTaskFunction.invoke("Tarea nueva", null)

        assertEquals(CreateTaskFunction.Result.Created::class, result::class)
        coVerify(exactly = 1) { taskRepository.addTask(any()) }
    }

    @Test
    fun `pepinillo plus user unlimited even at limit`() = runTest {
        buildGate(SubscriptionTier.PEPINILLO_PLUS)
        every { taskRepository.getActiveCount() } returns flowOf(FeatureGate.FREE_TASK_LIMIT + 5)

        val result = createTaskFunction.invoke("Tarea nueva", null)

        assertEquals(CreateTaskFunction.Result.Created::class, result::class)
        coVerify(exactly = 1) { taskRepository.addTask(any()) }
    }

    // ---------------------------------------------------------------
    // Persisted shape (same defaults as quick-add)
    // ---------------------------------------------------------------

    @Test
    fun `sortOrder appends after repository max`() = runTest {
        buildGate(SubscriptionTier.FREE)
        every { taskRepository.getAllTasks() } returns flowOf(
            listOf(Task(id = "seed", title = "Existing", sortOrder = 7))
        )

        createTaskFunction.invoke("Second", null)

        coVerify { taskRepository.addTask(match { it.sortOrder == 8 }) }
    }

    @Test
    fun `created task is not completed and has default pomodoros`() = runTest {
        buildGate(SubscriptionTier.FREE)

        createTaskFunction.invoke("Tarea", null)

        coVerify {
            taskRepository.addTask(
                match {
                    !it.isCompleted && it.estimatedPomodoros == 1 && it.completedPomodoros == 0
                }
            )
        }
    }

    @Test
    fun `repository failure reports storage error`() = runTest {
        buildGate(SubscriptionTier.FREE)
        coEvery { taskRepository.addTask(any()) } returns Result.failure(IllegalStateException("db down"))

        val result = createTaskFunction.invoke("Tarea", null)

        assertEquals(CreateTaskFunction.Result.Rejected(CreateTaskFunction.RejectionReason.STORAGE_ERROR), result)
    }

    @Test
    fun `created result carries task id and title`() = runTest {
        buildGate(SubscriptionTier.FREE)
        val captured = slot<Task>()
        coEvery { taskRepository.addTask(capture(captured)) } returns Result.success(Unit)

        val result = createTaskFunction.invoke("Tarea", null)

        result as CreateTaskFunction.Result.Created
        assertEquals(captured.captured.id, result.taskId)
        assertEquals("Tarea", result.title)
        assertNull(result.notes)
    }
}
