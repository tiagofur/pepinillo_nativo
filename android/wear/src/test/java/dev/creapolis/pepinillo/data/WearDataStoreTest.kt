package dev.creapolis.pepinillo.data

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

class WearDataStoreTest {

    @Before
    fun setUp() {
        WearDataStore.updateTimer(WearTimerState())
        WearDataStore.updateTasks(emptyList())
        WearDataStore.updateStats(WearStatsState())
        WearDataStore.updatePendingCount(0)
        WearDataStore.updateLastSyncAtMillis(null)
    }

    @Test
    fun `updateTasks replaces current wearable tasks`() {
        WearDataStore.updateTasks(
            listOf(
                WearTask("task-1", "Deep work", "DEEP", "2/4"),
                WearTask("task-2", "Inbox", "ADMIN", ""),
            ),
        )

        val tasks = WearDataStore.tasks.value
        assertEquals(2, tasks.size)
        assertEquals("task-1", tasks[0].id)
        assertEquals("Deep work", tasks[0].title)
        assertEquals("DEEP", tasks[0].energyEmoji)
        assertEquals("2/4", tasks[0].pomodoroProgress)
        assertEquals("task-2", tasks[1].id)
        assertEquals("Inbox", tasks[1].title)
    }

    @Test
    fun `updateTasksFromJson falls back to empty list on invalid json`() {
        WearDataStore.updateTasks(listOf(WearTask("old", "Old", "ADMIN", "1/1")))

        WearDataStore.updateTasksFromJson("{not-valid-json}")

        assertTrue(WearDataStore.tasks.value.isEmpty())
    }

    @Test
    fun `timer and stats updates are reflected in current state`() {
        WearDataStore.updateTimer(
            WearTimerState(
                mode = "Flow",
                status = "Running",
                displayTime = "03:25",
                progress = 0.42f,
                isConnected = true,
            ),
        )
        WearDataStore.updateStats(
            WearStatsState(
                totalMinutes = 95,
                sessions = 4,
                streak = 6,
                completedTasks = 7,
            ),
        )
        WearDataStore.updatePendingCount(3)
        WearDataStore.updateLastSyncAtMillis(123_456L)

        val timer = WearDataStore.timerState.value
        val stats = WearDataStore.stats.value

        assertEquals("Flow", timer.mode)
        assertEquals("Running", timer.status)
        assertEquals("03:25", timer.displayTime)
        assertEquals(0.42f, timer.progress, 0.0001f)
        assertTrue(timer.isConnected)
        assertEquals(95, stats.totalMinutes)
        assertEquals(4, stats.sessions)
        assertEquals(6, stats.streak)
        assertEquals(7, stats.completedTasks)
        assertEquals(3, WearDataStore.pendingCommandCount.value)
        assertEquals(123_456L, WearDataStore.lastSyncAtMillis.value)
        assertFalse(WearDataStore.tasks.value.isNotEmpty())
    }
}
