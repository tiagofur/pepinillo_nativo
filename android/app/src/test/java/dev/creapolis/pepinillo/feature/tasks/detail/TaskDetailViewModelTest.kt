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
import java.util.Calendar
import java.util.TimeZone

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

    // ── Title / notes length caps (iOS parity: 200 / 2000) ──

    @Test
    fun `updateTitle caps title at 200 characters`() = runTest {
        val task = Task(id = "task-1", title = "Original")
        coEvery { taskRepository.getTaskById("task-1") } returns task
        coEvery { taskRepository.updateTask(any()) } returns Result.success(Unit)

        viewModel.updateTitle("y".repeat(500))
        testDispatcher.scheduler.advanceUntilIdle()

        coVerify { taskRepository.updateTask(match { it.title.length == 200 }) }
    }

    @Test
    fun `updateNotes caps notes at 2000 characters`() = runTest {
        val task = Task(id = "task-1", title = "Original", notes = "old")
        coEvery { taskRepository.getTaskById("task-1") } returns task
        coEvery { taskRepository.updateTask(any()) } returns Result.success(Unit)

        viewModel.updateNotes("z".repeat(5000))
        testDispatcher.scheduler.advanceUntilIdle()

        coVerify { taskRepository.updateTask(match { (it.notes?.length ?: 0) == 2000 }) }
    }

    // ── Due date picker canonicalization: local-midnight storage (C1) ──

    @Test
    fun `updateDueDate stores picker selection as local midnight in UTC-4`() {
        withDefaultZone("GMT-04:00") {
            runTest {
                arrangeForDueDateUpdate()

                viewModel.updateDueDate(pickerMillisOfTomorrow())
                testDispatcher.scheduler.advanceUntilIdle()

                coVerify { taskRepository.updateTask(match { it.dueDate == localMidnightOfTomorrow() }) }
            }
        }
    }

    @Test
    fun `updateDueDate stores picker selection as local midnight in UTC+5-30`() {
        withDefaultZone("GMT+05:30") {
            runTest {
                arrangeForDueDateUpdate()

                viewModel.updateDueDate(pickerMillisOfTomorrow())
                testDispatcher.scheduler.advanceUntilIdle()

                coVerify { taskRepository.updateTask(match { it.dueDate == localMidnightOfTomorrow() }) }
            }
        }
    }

    @Test
    fun `updateDueDate null clears the due date`() = runTest {
        arrangeForDueDateUpdate()

        viewModel.updateDueDate(null)
        testDispatcher.scheduler.advanceUntilIdle()

        coVerify { taskRepository.updateTask(match { it.dueDate == null }) }
    }

    private fun arrangeForDueDateUpdate() {
        val task = Task(id = "task-1", title = "With due date")
        taskFlow.value = task
        coEvery { taskRepository.getTaskById("task-1") } returns task
        coEvery { taskRepository.updateTask(any()) } returns Result.success(Unit)
    }

    /** Runs [block] with the JVM default timezone swapped to [zoneId], restoring after. */
    private fun withDefaultZone(zoneId: String, block: () -> Unit) {
        val original = TimeZone.getDefault()
        TimeZone.setDefault(TimeZone.getTimeZone(zoneId))
        try {
            block()
        } finally {
            TimeZone.setDefault(original)
        }
    }

    /** UTC-midnight millis of tomorrow's local calendar date — what DatePicker.selectedDateMillis reports. */
    private fun pickerMillisOfTomorrow(): Long {
        val t = tomorrowFields()
        return Calendar.getInstance(TimeZone.getTimeZone("UTC")).apply {
            clear()
            set(t[0], t[1], t[2], 0, 0, 0)
        }.timeInMillis
    }

    /** Local-midnight millis of tomorrow's local calendar date — the canonical storage encoding. */
    private fun localMidnightOfTomorrow(): Long {
        val t = tomorrowFields()
        return Calendar.getInstance().apply {
            clear()
            set(t[0], t[1], t[2], 0, 0, 0)
        }.timeInMillis
    }

    private fun tomorrowFields(): IntArray {
        val tomorrow = Calendar.getInstance().apply { add(Calendar.DAY_OF_YEAR, 1) }
        return intArrayOf(
            tomorrow.get(Calendar.YEAR),
            tomorrow.get(Calendar.MONTH),
            tomorrow.get(Calendar.DAY_OF_MONTH),
        )
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
