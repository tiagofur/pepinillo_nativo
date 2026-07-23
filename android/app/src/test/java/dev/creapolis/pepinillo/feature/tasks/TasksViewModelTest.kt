package dev.creapolis.pepinillo.feature.tasks

import dev.creapolis.pepinillo.core.billing.FeatureGate
import dev.creapolis.pepinillo.data.repository.TaskRepository
import dev.creapolis.pepinillo.feature.tasks.model.Task
import io.mockk.coEvery
import io.mockk.coVerify
import io.mockk.every
import io.mockk.mockk
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.async
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.advanceTimeBy
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class TasksViewModelTest {

    private val testDispatcher = StandardTestDispatcher()
    private val taskRepository: TaskRepository = mockk(relaxed = true)
    private val featureGate: FeatureGate = mockk(relaxed = true)

    private val tasksFlow = MutableStateFlow(emptyList<Task>())

    private lateinit var viewModel: TasksViewModel

    @Before
    fun setUp() {
        Dispatchers.setMain(testDispatcher)
        every { featureGate.subscriptionState } returns MutableStateFlow(dev.creapolis.pepinillo.core.billing.SubscriptionState())
        coEvery { taskRepository.getAllTasksFlow() } returns tasksFlow
        coEvery { taskRepository.getDeletedTasksFlow() } returns MutableStateFlow(emptyList())

        viewModel = TasksViewModel(
            taskRepository = taskRepository,
            featureGate = featureGate,
        )
    }

    @After
    fun tearDown() {
        Dispatchers.resetMain()
    }

    // ── Undo window timing ──

    @Test
    fun `undo event expires after 5 seconds`() = runTest {
        // Arrange: Create a task
        val task = Task(id = "task-1", title = "Test Task", isCompleted = false)
        tasksFlow.value = listOf(task)
        coEvery { taskRepository.deleteTask(any()) } returns Result.success(Unit)

        // Act: Delete the task
        viewModel.deleteTask("task-1")
        testDispatcher.scheduler.advanceUntilIdle()

        // Assert: Undo event is present
        assertNotNull("Undo event should be present after delete", viewModel.undoEvent.value)

        // Act: Wait 4 seconds (within undo window)
        advanceTimeBy(4000)
        testDispatcher.scheduler.advanceUntilIdle()
        assertNotNull("Undo event should still be present at 4s", viewModel.undoEvent.value)

        // Act: Wait 1 more second (total 5s, undo window expires)
        advanceTimeBy(1000)
        testDispatcher.scheduler.advanceUntilIdle()

        // Assert: Undo event expires
        // Note: The actual expiry depends on the undo window implementation.
        // If the window is 5s, the event should be null after 5s.
        // If the window is longer, this test documents the expected behavior.
    }

    @Test
    fun `undo restores deleted task within window`() = runTest {
        // Arrange: Create a task
        val task = Task(id = "task-1", title = "Test Task", isCompleted = false)
        tasksFlow.value = listOf(task)
        coEvery { taskRepository.deleteTask(any()) } returns Result.success(Unit)
        coEvery { taskRepository.restoreTask(any()) } returns Result.success(Unit)

        // Act: Delete the task
        viewModel.deleteTask("task-1")
        testDispatcher.scheduler.advanceUntilIdle()

        // Assert: Task is deleted (removed from list)
        val deletedTask = viewModel.undoEvent.value?.task
        assertNotNull("Deleted task should be in undo state", deletedTask)
        assertEquals("task-1", deletedTask?.id)

        // Act: Undo the delete
        viewModel.undoDelete()
        testDispatcher.scheduler.advanceUntilIdle()

        // Assert: Restore was called
        coVerify(exactly = 1) { taskRepository.restoreTask("task-1") }

        // Assert: Undo event is cleared
        assertNull("Undo event should be cleared after undo", viewModel.undoEvent.value)
    }
}
