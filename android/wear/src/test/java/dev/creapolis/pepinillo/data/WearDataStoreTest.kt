package dev.creapolis.pepinillo.data

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
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
        WearDataStore.resetDiagnostics()
    }

    // ── Original tests ──────────────────────────────────────────────────

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

    // ── updateTasksFromJson ─────────────────────────────────────────────

    @Test
    fun `updateTasksFromJson parses valid JSON with multiple tasks`() {
        val json = """
            [
                {"id":"t-1","title":"Write report","energyEmoji":"HIGH","pomodoroProgress":"1/3"},
                {"id":"t-2","title":"Review PR","energyEmoji":"MED","pomodoroProgress":"0/2"},
                {"id":"t-3","title":"Quick call","energyEmoji":"LOW","pomodoroProgress":""}
            ]
        """.trimIndent()

        WearDataStore.updateTasksFromJson(json)

        val tasks = WearDataStore.tasks.value
        assertEquals(3, tasks.size)
        assertEquals("t-1", tasks[0].id)
        assertEquals("Write report", tasks[0].title)
        assertEquals("HIGH", tasks[0].energyEmoji)
        assertEquals("1/3", tasks[0].pomodoroProgress)
        assertEquals("t-2", tasks[1].id)
        assertEquals("Review PR", tasks[1].title)
        assertEquals("MED", tasks[1].energyEmoji)
        assertEquals("0/2", tasks[1].pomodoroProgress)
        assertEquals("t-3", tasks[2].id)
        assertEquals("Quick call", tasks[2].title)
        assertEquals("LOW", tasks[2].energyEmoji)
        assertEquals("", tasks[2].pomodoroProgress)
    }

    @Test
    fun `updateTasksFromJson with empty JSON array results in empty list`() {
        WearDataStore.updateTasks(listOf(WearTask("old", "Old task", "ADMIN", "1/1")))

        WearDataStore.updateTasksFromJson("[]")

        assertTrue(WearDataStore.tasks.value.isEmpty())
    }

    // ── recordSyncEvent ─────────────────────────────────────────────────

    @Test
    fun `recordSyncEvent increments sync event counter`() {
        assertEquals(0, WearDataStore.diagnostics.value.syncEvents)

        WearDataStore.recordSyncEvent()
        assertEquals(1, WearDataStore.diagnostics.value.syncEvents)

        WearDataStore.recordSyncEvent()
        WearDataStore.recordSyncEvent()
        assertEquals(3, WearDataStore.diagnostics.value.syncEvents)
    }

    // ── recordSyncFailure ───────────────────────────────────────────────

    @Test
    fun `recordSyncFailure increments failure counter and stores message`() {
        assertEquals(0, WearDataStore.diagnostics.value.syncFailures)
        assertNull(WearDataStore.diagnostics.value.lastError)

        WearDataStore.recordSyncFailure("timeout")
        assertEquals(1, WearDataStore.diagnostics.value.syncFailures)
        assertEquals("timeout", WearDataStore.diagnostics.value.lastError)

        WearDataStore.recordSyncFailure("disconnected")
        assertEquals(2, WearDataStore.diagnostics.value.syncFailures)
        assertEquals("disconnected", WearDataStore.diagnostics.value.lastError)
    }

    // ── recordFlushAttempt ──────────────────────────────────────────────

    @Test
    fun `recordFlushAttempt with positive count increments flush attempts`() {
        WearDataStore.recordFlushAttempt(5)
        assertEquals(5, WearDataStore.diagnostics.value.flushAttempts)

        WearDataStore.recordFlushAttempt(3)
        assertEquals(8, WearDataStore.diagnostics.value.flushAttempts)
    }

    @Test
    fun `recordFlushAttempt with zero is a no-op`() {
        WearDataStore.recordFlushAttempt(2)
        assertEquals(2, WearDataStore.diagnostics.value.flushAttempts)

        WearDataStore.recordFlushAttempt(0)
        assertEquals(2, WearDataStore.diagnostics.value.flushAttempts)
    }

    // ── recordFlushFailures ─────────────────────────────────────────────

    @Test
    fun `recordFlushFailures with count and message updates diagnostics`() {
        WearDataStore.recordFlushFailures(2, "network error")
        assertEquals(2, WearDataStore.diagnostics.value.flushFailures)
        assertEquals("network error", WearDataStore.diagnostics.value.lastError)

        WearDataStore.recordFlushFailures(3, "timeout")
        assertEquals(5, WearDataStore.diagnostics.value.flushFailures)
        assertEquals("timeout", WearDataStore.diagnostics.value.lastError)
    }

    // ── updateConnectedNodes ────────────────────────────────────────────

    @Test
    fun `updateConnectedNodes sets count and names`() {
        WearDataStore.updateConnectedNodes(2, listOf("Phone", "Tablet"))

        val diag = WearDataStore.diagnostics.value
        assertEquals(2, diag.connectedNodeCount)
        assertEquals(listOf("Phone", "Tablet"), diag.connectedNodeNames)
    }

    @Test
    fun `updateConnectedNodes filters blank names`() {
        WearDataStore.updateConnectedNodes(3, listOf("Phone", "", "  ", "Watch"))

        val diag = WearDataStore.diagnostics.value
        assertEquals(3, diag.connectedNodeCount)
        assertEquals(listOf("Phone", "Watch"), diag.connectedNodeNames)
    }

    @Test
    fun `updateConnectedNodes coerces negative count to zero`() {
        WearDataStore.updateConnectedNodes(-1, listOf("Phone"))

        assertEquals(0, WearDataStore.diagnostics.value.connectedNodeCount)
    }

    // ── resetDiagnostics ────────────────────────────────────────────────

    @Test
    fun `resetDiagnostics clears all diagnostic fields`() {
        WearDataStore.recordSyncEvent()
        WearDataStore.recordSyncEvent()
        WearDataStore.recordSyncFailure("some error")
        WearDataStore.recordFlushAttempt(4)
        WearDataStore.recordFlushFailures(2, "flush error")
        WearDataStore.updateConnectedNodes(1, listOf("Phone"))

        val before = WearDataStore.diagnostics.value
        assertTrue(before.syncEvents > 0)
        assertTrue(before.syncFailures > 0)
        assertTrue(before.flushAttempts > 0)
        assertTrue(before.flushFailures > 0)
        assertTrue(before.connectedNodeCount > 0)
        assertTrue(before.connectedNodeNames.isNotEmpty())
        assertTrue(before.lastError != null)

        WearDataStore.resetDiagnostics()

        val after = WearDataStore.diagnostics.value
        assertEquals(0, after.syncEvents)
        assertEquals(0, after.syncFailures)
        assertEquals(0, after.flushAttempts)
        assertEquals(0, after.flushFailures)
        assertEquals(0, after.connectedNodeCount)
        assertTrue(after.connectedNodeNames.isEmpty())
        assertNull(after.lastError)
    }

    // ── updatePendingCount ──────────────────────────────────────────────

    @Test
    fun `updatePendingCount sets the pending command count`() {
        WearDataStore.updatePendingCount(7)
        assertEquals(7, WearDataStore.pendingCommandCount.value)

        WearDataStore.updatePendingCount(0)
        assertEquals(0, WearDataStore.pendingCommandCount.value)
    }

    // ── updateLastSyncAtMillis ──────────────────────────────────────────

    @Test
    fun `updateLastSyncAtMillis sets value`() {
        WearDataStore.updateLastSyncAtMillis(999_999L)
        assertEquals(999_999L, WearDataStore.lastSyncAtMillis.value)
    }

    @Test
    fun `updateLastSyncAtMillis with null clears value`() {
        WearDataStore.updateLastSyncAtMillis(500L)
        assertEquals(500L, WearDataStore.lastSyncAtMillis.value)

        WearDataStore.updateLastSyncAtMillis(null)
        assertNull(WearDataStore.lastSyncAtMillis.value)
    }
}
