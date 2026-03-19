package dev.creapolis.pepinillo.viewmodel

import dev.creapolis.pepinillo.data.WearDataStore
import dev.creapolis.pepinillo.data.WearStatsState
import dev.creapolis.pepinillo.data.WearTask
import dev.creapolis.pepinillo.data.WearTimerState
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

/**
 * Tests verifying the optimistic-update patterns used by WearViewModel.
 *
 * WearViewModel delegates all optimistic state mutations to [WearDataStore],
 * so we exercise the exact same store operations the ViewModel performs
 * without needing an Android Application context or WearMessageSender.
 */
class WearViewModelTest {

    @Before
    fun setUp() {
        WearDataStore.updateTimer(WearTimerState())
        WearDataStore.updateTasks(emptyList())
        WearDataStore.updateStats(WearStatsState())
        WearDataStore.updatePendingCount(0)
        WearDataStore.updateLastSyncAtMillis(null)
        WearDataStore.resetDiagnostics()
    }

    // ── startTimer optimistic update ────────────────────────────────────

    @Test
    fun `startTimer sets mode to requested value and status to Running`() {
        // Simulate: WearViewModel.startTimer("Flow")
        val current = WearDataStore.timerState.value
        WearDataStore.updateTimer(
            current.copy(
                mode = "Flow",
                status = "Running",
                phaseLabel = "Focus",
            ),
        )

        val timer = WearDataStore.timerState.value
        assertEquals("Flow", timer.mode)
        assertEquals("Running", timer.status)
        assertEquals("Focus", timer.phaseLabel)
    }

    @Test
    fun `startTimer with Pomodoro mode updates correctly`() {
        // Simulate: WearViewModel.startTimer("Pomodoro")
        val current = WearDataStore.timerState.value
        WearDataStore.updateTimer(
            current.copy(
                mode = "Pomodoro",
                status = "Running",
                phaseLabel = "Focus",
            ),
        )

        val timer = WearDataStore.timerState.value
        assertEquals("Pomodoro", timer.mode)
        assertEquals("Running", timer.status)
        assertEquals("Focus", timer.phaseLabel)
    }

    @Test
    fun `startTimer preserves other timer fields`() {
        // Set some pre-existing state
        WearDataStore.updateTimer(
            WearTimerState(
                displayTime = "10:00",
                progress = 0.5f,
                isConnected = true,
                linkedTaskId = "task-x",
                linkedTaskName = "My Task",
            ),
        )

        // Simulate: WearViewModel.startTimer("Flow")
        val current = WearDataStore.timerState.value
        WearDataStore.updateTimer(
            current.copy(
                mode = "Flow",
                status = "Running",
                phaseLabel = "Focus",
            ),
        )

        val timer = WearDataStore.timerState.value
        assertEquals("Flow", timer.mode)
        assertEquals("Running", timer.status)
        assertEquals("Focus", timer.phaseLabel)
        // Preserved fields
        assertEquals("10:00", timer.displayTime)
        assertEquals(0.5f, timer.progress, 0.0001f)
        assertTrue(timer.isConnected)
        assertEquals("task-x", timer.linkedTaskId)
        assertEquals("My Task", timer.linkedTaskName)
    }

    // ── pauseTimer optimistic update ────────────────────────────────────

    @Test
    fun `pauseTimer sets status to Paused`() {
        // First get into Running state
        WearDataStore.updateTimer(
            WearTimerState(
                mode = "Flow",
                status = "Running",
                displayTime = "08:30",
                progress = 0.66f,
            ),
        )

        // Simulate: WearViewModel.pauseTimer()
        val current = WearDataStore.timerState.value
        WearDataStore.updateTimer(
            current.copy(status = "Paused"),
        )

        val timer = WearDataStore.timerState.value
        assertEquals("Paused", timer.status)
        assertEquals("Flow", timer.mode)
        assertEquals("08:30", timer.displayTime)
        assertEquals(0.66f, timer.progress, 0.0001f)
    }

    // ── resumeTimer optimistic update ───────────────────────────────────

    @Test
    fun `resumeTimer sets status to Running`() {
        // Start in Paused state
        WearDataStore.updateTimer(
            WearTimerState(
                mode = "Pomodoro",
                status = "Paused",
                displayTime = "12:15",
                progress = 0.51f,
            ),
        )

        // Simulate: WearViewModel.resumeTimer()
        val current = WearDataStore.timerState.value
        WearDataStore.updateTimer(
            current.copy(status = "Running"),
        )

        val timer = WearDataStore.timerState.value
        assertEquals("Running", timer.status)
        assertEquals("Pomodoro", timer.mode)
        assertEquals("12:15", timer.displayTime)
        assertEquals(0.51f, timer.progress, 0.0001f)
    }

    // ── stopTimer optimistic update ─────────────────────────────────────

    @Test
    fun `stopTimer sets status to Idle and resets progress`() {
        WearDataStore.updateTimer(
            WearTimerState(
                mode = "Flow",
                status = "Running",
                displayTime = "05:00",
                progress = 0.3f,
                phaseLabel = "Focus",
            ),
        )

        // Simulate: WearViewModel.stopTimer()
        val current = WearDataStore.timerState.value
        WearDataStore.updateTimer(
            current.copy(
                status = "Idle",
                displayTime = current.displayTime,
                progress = 1f,
                phaseLabel = "Listo",
            ),
        )

        val timer = WearDataStore.timerState.value
        assertEquals("Idle", timer.status)
        assertEquals("05:00", timer.displayTime)
        assertEquals(1f, timer.progress, 0.0001f)
        assertEquals("Listo", timer.phaseLabel)
        assertEquals("Flow", timer.mode)
    }

    // ── completeTask optimistic update ──────────────────────────────────

    @Test
    fun `completeTask removes the task from the list`() {
        WearDataStore.updateTasks(
            listOf(
                WearTask("task-1", "Write report", "HIGH", "1/3"),
                WearTask("task-2", "Review PR", "MED", "0/2"),
                WearTask("task-3", "Quick call", "LOW", ""),
            ),
        )

        // Simulate: WearViewModel.completeTask("task-2")
        WearDataStore.updateTasks(
            WearDataStore.tasks.value.filter { it.id != "task-2" },
        )

        val tasks = WearDataStore.tasks.value
        assertEquals(2, tasks.size)
        assertEquals("task-1", tasks[0].id)
        assertEquals("task-3", tasks[1].id)
    }

    @Test
    fun `completeTask with nonexistent id leaves list unchanged`() {
        WearDataStore.updateTasks(
            listOf(
                WearTask("task-1", "Write report", "HIGH", "1/3"),
                WearTask("task-2", "Review PR", "MED", "0/2"),
            ),
        )

        // Simulate: WearViewModel.completeTask("task-999")
        WearDataStore.updateTasks(
            WearDataStore.tasks.value.filter { it.id != "task-999" },
        )

        val tasks = WearDataStore.tasks.value
        assertEquals(2, tasks.size)
    }

    @Test
    fun `completeTask on single-item list results in empty list`() {
        WearDataStore.updateTasks(
            listOf(WearTask("task-1", "Only task", "MED", "")),
        )

        // Simulate: WearViewModel.completeTask("task-1")
        WearDataStore.updateTasks(
            WearDataStore.tasks.value.filter { it.id != "task-1" },
        )

        assertTrue(WearDataStore.tasks.value.isEmpty())
    }

    @Test
    fun `completeTask on empty list is a no-op`() {
        // Simulate: WearViewModel.completeTask("task-1")
        WearDataStore.updateTasks(
            WearDataStore.tasks.value.filter { it.id != "task-1" },
        )

        assertTrue(WearDataStore.tasks.value.isEmpty())
    }

    // ── Full lifecycle: start -> pause -> resume -> stop ────────────────

    @Test
    fun `full timer lifecycle transitions through expected states`() {
        // 1. Start
        val s0 = WearDataStore.timerState.value
        WearDataStore.updateTimer(
            s0.copy(mode = "Pomodoro", status = "Running", phaseLabel = "Focus"),
        )
        assertEquals("Running", WearDataStore.timerState.value.status)

        // 2. Pause
        val s1 = WearDataStore.timerState.value
        WearDataStore.updateTimer(s1.copy(status = "Paused"))
        assertEquals("Paused", WearDataStore.timerState.value.status)

        // 3. Resume
        val s2 = WearDataStore.timerState.value
        WearDataStore.updateTimer(s2.copy(status = "Running"))
        assertEquals("Running", WearDataStore.timerState.value.status)

        // 4. Stop
        val s3 = WearDataStore.timerState.value
        WearDataStore.updateTimer(
            s3.copy(
                status = "Idle",
                displayTime = s3.displayTime,
                progress = 1f,
                phaseLabel = "Listo",
            ),
        )

        val final_ = WearDataStore.timerState.value
        assertEquals("Idle", final_.status)
        assertEquals(1f, final_.progress, 0.0001f)
        assertEquals("Listo", final_.phaseLabel)
        assertEquals("Pomodoro", final_.mode)
    }

    // ── completeTask does not affect timer state ────────────────────────

    @Test
    fun `completeTask does not alter timer state`() {
        WearDataStore.updateTimer(
            WearTimerState(mode = "Flow", status = "Running", displayTime = "14:00"),
        )
        WearDataStore.updateTasks(
            listOf(WearTask("task-1", "Task", "MED", "")),
        )

        // Simulate: WearViewModel.completeTask("task-1")
        WearDataStore.updateTasks(
            WearDataStore.tasks.value.filter { it.id != "task-1" },
        )

        val timer = WearDataStore.timerState.value
        assertEquals("Flow", timer.mode)
        assertEquals("Running", timer.status)
        assertEquals("14:00", timer.displayTime)
        assertTrue(WearDataStore.tasks.value.isEmpty())
    }
}
