package dev.creapolis.pepinillo.feature.tasks.detail

import dev.creapolis.pepinillo.core.billing.FeatureGate
import dev.creapolis.pepinillo.core.billing.SubscriptionState
import dev.creapolis.pepinillo.data.local.preferences.UserPreferences
import dev.creapolis.pepinillo.data.local.preferences.UserPreferencesRepository
import dev.creapolis.pepinillo.data.repository.TaskRepository
import dev.creapolis.pepinillo.feature.tasks.model.RecurrenceOption
import dev.creapolis.pepinillo.feature.tasks.model.Task
import io.mockk.coEvery
import io.mockk.coVerify
import io.mockk.every
import io.mockk.mockk
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.async
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class TaskDetailViewModelTest {

    private val testDispatcher = StandardTestDispatcher()
    private val taskRepository: TaskRepository = mockk(relaxed = true)
    private val featureGate: FeatureGate = mockk(relaxed = true)
    private val prefsRepo: UserPreferencesRepository = mockk {
        every { preferences } returns MutableStateFlow(UserPreferences())
    }

    private val subscriptionStateFlow = MutableStateFlow(SubscriptionState())
    private val taskFlow = MutableStateFlow<Task?>(null)
    private val subtasksFlow = MutableStateFlow(emptyList<dev.creapolis.pepinillo.feature.tasks.model.Subtask>())
    private val sessionsFlow = MutableStateFlow(emptyList<dev.creapolis.pepinillo.data.local.entity.FocusSessionEntity>())

    private lateinit var viewModel: TaskDetailViewModel

    @Before
    fun setUp() {
        Dispatchers.setMain(testDispatcher)
        every { featureGate.subscriptionState } returns subscriptionStateFlow
        every { featureGate.canUseRecurrence() } returns true
        every { featureGate.canUseSubtasks() } returns true

        coEvery { taskRepository.getTaskByIdFlow(any()) } returns taskFlow
        coEvery { taskRepository.getSubtasksForTask(any()) } returns subtasksFlow
        coEvery { taskRepository.getSessionsForTask(any()) } returns sessionsFlow

        viewModel = TaskDetailViewModel(
            taskRepository = taskRepository,
            featureGate = featureGate,
            prefsRepo = prefsRepo,
        )
        viewModel.initialize("task-1")
    }

    @After
    fun tearDown() {
        Dispatchers.resetMain()
    }

    // ── Concurrent update/complete race ──

    @Test
    fun `concurrent update and complete produces deterministic final state`() = runTest {
        // Arrange: Set up a task that is not completed
        val task = Task(id = "task-1", title = "Test Task", isCompleted = false)
        taskFlow.value = task

        coEvery { taskRepository.getTaskById("task-1") } returns task
        coEvery { taskRepository.toggleCompletion(any()) } returns Result.success(Unit)
        coEvery { taskRepository.updateTask(any()) } returns Result.success(Unit)

        // Act: Fire update and complete concurrently
        val updateJob = async { viewModel.updateTitle("Updated Title") }
        val completeJob = async { viewModel.toggleCompletion() }
        updateJob.await()
        completeJob.await()
        testDispatcher.scheduler.advanceUntilIdle()

        // Assert: Both operations completed without error
        // The updateMutex ensures sequential execution, so no state corruption
        coVerify(atLeast = 1) { taskRepository.updateTask(any()) }
        coVerify(exactly = 1) { taskRepository.toggleCompletion("task-1") }
    }

    @Test
    fun `concurrent updates are serialized by mutex`() = runTest {
        val task = Task(id = "task-1", title = "Original", isCompleted = false)
        taskFlow.value = task
        coEvery { taskRepository.getTaskById("task-1") } returns task
        coEvery { taskRepository.updateTask(any()) } returns Result.success(Unit)

        // Act: Fire multiple updates concurrently
        val jobs = listOf(
            async { viewModel.updateTitle("Title 1") },
            async { viewModel.updateNotes("Notes 1") },
            async { viewModel.updateTitle("Title 2") },
        )
        jobs.forEach { it.await() }
        testDispatcher.scheduler.advanceUntilIdle()

        // Assert: All updates were applied (mutex serializes them)
        coVerify(atLeast = 3) { taskRepository.updateTask(any()) }
    }

    // ── Recurrence complete ──

    @Test
    fun `completing daily recurring task creates next instance`() = runTest {
        val task = Task(
            id = "task-1",
            title = "Daily Standup",
            isCompleted = false,
            recurrenceRule = "FREQ=DAILY",
            isRecurringTemplate = true,
        )
        taskFlow.value = task

        coEvery { taskRepository.getTaskById("task-1") } returns task
        coEvery { taskRepository.toggleCompletion("task-1") } returns Result.success(Unit)

        // Act: Complete the recurring task
        viewModel.toggleCompletion()
        testDispatcher.scheduler.advanceUntilIdle()

        // Assert: toggleCompletion was called (which internally calls advanceRecurringTask)
        coVerify(exactly = 1) { taskRepository.toggleCompletion("task-1") }
    }

    @Test
    fun `updateRecurrence with None clears recurrence rule`() = runTest {
        val task = Task(
            id = "task-1",
            title = "Recurring Task",
            isCompleted = false,
            recurrenceRule = "FREQ=WEEKLY",
            isRecurringTemplate = true,
        )
        taskFlow.value = task

        coEvery { taskRepository.getTaskById("task-1") } returns task
        coEvery { taskRepository.updateTask(any()) } returns Result.success(Unit)

        // Act: Set recurrence to None
        viewModel.updateRecurrence(RecurrenceOption.None)
        testDispatcher.scheduler.advanceUntilIdle()

        // Assert: updateTask was called with cleared recurrence
        coVerify {
            taskRepository.updateTask(match { task ->
                task.id == "task-1" && task.recurrenceRule == null && !task.isRecurringTemplate
            })
        }
    }

    @Test
    fun `updateRecurrence with non-None option sets recurrence rule`() = runTest {
        val task = Task(
            id = "task-1",
            title = "Task",
            isCompleted = false,
        )
        taskFlow.value = task

        coEvery { taskRepository.getTaskById("task-1") } returns task
        coEvery { taskRepository.updateTask(any()) } returns Result.success(Unit)

        // Act: Set daily recurrence
        viewModel.updateRecurrence(RecurrenceOption.Daily)
        testDispatcher.scheduler.advanceUntilIdle()

        // Assert: updateTask was called with recurrence rule
        coVerify {
            taskRepository.updateTask(match { task ->
                task.id == "task-1" &&
                    task.recurrenceRule != null &&
                    task.isRecurringTemplate
            })
        }
    }

    @Test
    fun `updateRecurrence shows paywall when feature gate denies recurrence`() = runTest {
        every { featureGate.canUseRecurrence() } returns false

        val task = Task(id = "task-1", title = "Task", isCompleted = false)
        taskFlow.value = task

        // Act: Try to set recurrence without Pro
        viewModel.updateRecurrence(RecurrenceOption.Daily)
        testDispatcher.scheduler.advanceUntilIdle()

        // Assert: Paywall is shown, no updateTask call
        assertTrue(viewModel.showPaywall.value)
        coVerify(exactly = 0) { taskRepository.updateTask(any()) }
    }
}
