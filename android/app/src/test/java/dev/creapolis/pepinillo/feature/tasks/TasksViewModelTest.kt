package dev.creapolis.pepinillo.feature.tasks

import android.content.Context
import dev.creapolis.pepinillo.core.billing.FeatureGate
import dev.creapolis.pepinillo.core.billing.SubscriptionState
import dev.creapolis.pepinillo.data.repository.TaskRepository
import dev.creapolis.pepinillo.domain.timer.FocusEngine
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
    private val focusEngine: FocusEngine = mockk(relaxed = true)
    private val context: Context = mockk(relaxed = true)

    private val tasksFlow = MutableStateFlow(emptyList<Task>())

    private lateinit var viewModel: TasksViewModel

    @Before
    fun setUp() {
        Dispatchers.setMain(testDispatcher)
        every { featureGate.subscriptionState } returns MutableStateFlow(SubscriptionState())
        coEvery { taskRepository.getAllTasks() } returns tasksFlow

        viewModel = TasksViewModel(
            taskRepository = taskRepository,
            featureGate = featureGate,
            focusEngine = focusEngine,
            context = context,
        )
    }

    @After
    fun tearDown() {
        Dispatchers.resetMain()
    }

    // ── Undo window timing ──

    @Test
    fun `undo event expires after 10 seconds`() = runTest {
        // Arrange: Create a task
        val task = Task(id = "task-1", title = "Test Task", isCompleted = false)
        tasksFlow.value = listOf(task)
        coEvery { taskRepository.deleteTaskWithUndo("task-1") } returns Result.success(task)

        // Act: Delete the task
        viewModel.deleteTask("task-1")
        testDispatcher.scheduler.advanceUntilIdle()

        // Assert: Undo event is present
        assertNotNull("Undo event should be present after delete", viewModel.undoEvent.value)

        // Act: Wait 9 seconds (within undo window)
        advanceTimeBy(9000)
        testDispatcher.scheduler.advanceUntilIdle()
        assertNotNull("Undo event should still be present at 9s", viewModel.undoEvent.value)

        // Act: Wait 1 more second (total 10s, undo window expires)
        advanceTimeBy(1000)
        testDispatcher.scheduler.advanceUntilIdle()

        // Assert: Undo event expires
        assertNull("Undo event should be null after 10s", viewModel.undoEvent.value)
    }

    @Test
    fun `undo restores deleted task within window`() = runTest {
        // Arrange: Create a task
        val task = Task(id = "task-1", title = "Test Task", isCompleted = false)
        tasksFlow.value = listOf(task)
        coEvery { taskRepository.deleteTaskWithUndo("task-1") } returns Result.success(task)
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
        coVerify(exactly = 1) { taskRepository.restoreTask(any()) }

        // Assert: Undo event is cleared
        assertNull("Undo event should be cleared after undo", viewModel.undoEvent.value)
    }
}
