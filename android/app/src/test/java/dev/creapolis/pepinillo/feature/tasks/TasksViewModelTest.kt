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
import io.mockk.slot
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.async
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.flowOf
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
import java.util.Calendar
import java.util.TimeZone

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
        // Run only the delete coroutine: advanceUntilIdle would also fast-forward the
        // 10s undo-expiry delay and clear the event before the first assertion.
        testDispatcher.scheduler.runCurrent()

        // Assert: Undo event is present
        assertNotNull("Undo event should be present after delete", viewModel.undoEvent.value)

        // Act: Wait 9 seconds (within undo window)
        testDispatcher.scheduler.advanceTimeBy(9000)
        testDispatcher.scheduler.runCurrent()
        assertNotNull("Undo event should still be present at 9s", viewModel.undoEvent.value)

        // Act: Wait 1 more second (total 10s, undo window expires)
        testDispatcher.scheduler.advanceTimeBy(1000)
        testDispatcher.scheduler.runCurrent()

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
        // Run only the delete coroutine (see expiry test note on advanceUntilIdle).
        testDispatcher.scheduler.runCurrent()

        // Assert: Task is deleted (removed from list)
        val deletedTask = viewModel.undoEvent.value?.task
        assertNotNull("Deleted task should be in undo state", deletedTask)
        assertEquals("task-1", deletedTask?.id)

        // Act: Undo the delete
        viewModel.undoDelete()
        testDispatcher.scheduler.runCurrent()

        // Assert: Restore was called
        coVerify(exactly = 1) { taskRepository.restoreTask(any()) }

        // Assert: Undo event is cleared
        assertNull("Undo event should be cleared after undo", viewModel.undoEvent.value)
    }

    // ── Quick add: authoritative limit, sort order, title cap ──

    @Test
    fun `addQuickTask checks the free-task limit against the repository count not stale uiState`() = runTest {
        // uiState still shows zero tasks (no collector attached), but the repository
        // reports 5 active tasks — the authoritative count must win the limit check.
        every { taskRepository.getActiveCount() } returns flowOf(5)
        every { featureGate.canAddTask(5) } returns false
        every { featureGate.canAddTask(0) } returns true

        viewModel.addQuickTask("racy task")
        testDispatcher.scheduler.advanceUntilIdle()

        assertTrue("Paywall must show when the repository count is over the limit", viewModel.showPaywall.value)
        coVerify(exactly = 0) { taskRepository.addTask(any()) }
    }

    @Test
    fun `addQuickTask derives sort order from max plus one`() = runTest {
        tasksFlow.value = listOf(
            Task(id = "a", title = "A", sortOrder = 3),
            Task(id = "b", title = "B", sortOrder = 7),
        )
        every { taskRepository.getActiveCount() } returns flowOf(2)
        every { featureGate.canAddTask(2) } returns true
        coEvery { taskRepository.addTask(any()) } returns Result.success(Unit)

        viewModel.addQuickTask("C")
        testDispatcher.scheduler.advanceUntilIdle()

        // list.size (2) would collide with an existing sort order; max+1 (8) does not.
        coVerify { taskRepository.addTask(match { it.sortOrder == 8 }) }
    }

    @Test
    fun `addQuickTask caps title at 200 characters`() = runTest {
        every { taskRepository.getActiveCount() } returns flowOf(0)
        every { featureGate.canAddTask(0) } returns true
        coEvery { taskRepository.addTask(any()) } returns Result.success(Unit)

        viewModel.addQuickTask("x".repeat(500))
        testDispatcher.scheduler.advanceUntilIdle()

        coVerify { taskRepository.addTask(match { it.title.length == 200 }) }
    }

    // ── Quick add in Upcoming: local-midnight encoding survives zone extremes (C1) ──

    @Test
    fun `quick add in upcoming stores local midnight tomorrow and lists in upcoming in UTC-4`() {
        withDefaultZone("GMT-04:00") {
            runTest {
                assertQuickAddUpcomingStoresLocalMidnight()
            }
        }
    }

    @Test
    fun `quick add in upcoming stores local midnight tomorrow and lists in upcoming in UTC+5-30`() {
        withDefaultZone("GMT+05:30") {
            runTest {
                assertQuickAddUpcomingStoresLocalMidnight()
            }
        }
    }

    private suspend fun assertQuickAddUpcomingStoresLocalMidnight() {
        val captured = slot<Task>()
        every { taskRepository.getActiveCount() } returns flowOf(0)
        every { featureGate.canAddTask(0) } returns true
        coEvery { taskRepository.addTask(capture(captured)) } returns Result.success(Unit)

        viewModel.selectFilter(TaskFilter.Upcoming)
        viewModel.addQuickTask("Tomorrow task")
        testDispatcher.scheduler.advanceUntilIdle()

        assertEquals("due tomorrow must be stored as local midnight", localMidnightOfTomorrow(), captured.captured.dueDate)

        val upcoming = TasksUiState(
            tasks = listOf(captured.captured),
            selectedFilter = TaskFilter.Upcoming,
        ).computeFilteredTasks()
        assertEquals("stored value must appear in Upcoming", listOf(captured.captured.id), upcoming.map { it.id })

        val today = TasksUiState(
            tasks = listOf(captured.captured),
            selectedFilter = TaskFilter.Today,
        ).computeFilteredTasks()
        assertTrue("stored value must not appear in Today", today.isEmpty())
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

    /** Local-midnight millis of tomorrow's local calendar date — the canonical storage encoding. */
    private fun localMidnightOfTomorrow(): Long {
        val tomorrow = Calendar.getInstance().apply { add(Calendar.DAY_OF_YEAR, 1) }
        return Calendar.getInstance().apply {
            clear()
            set(
                tomorrow.get(Calendar.YEAR),
                tomorrow.get(Calendar.MONTH),
                tomorrow.get(Calendar.DAY_OF_MONTH),
                0,
                0,
                0,
            )
        }.timeInMillis
    }
}
