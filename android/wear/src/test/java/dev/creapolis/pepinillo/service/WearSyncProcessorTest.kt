package dev.creapolis.pepinillo.service

import dev.creapolis.pepinillo.data.WearStatsState
import dev.creapolis.pepinillo.data.WearTask
import dev.creapolis.pepinillo.data.WearTimerState
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class WearSyncProcessorTest {

    @Test
    fun `timer sync updates store, persistence, sync mark and surfaces`() {
        val sink = FakeSink()
        val processor = WearSyncProcessor(sink)
        val timer = WearTimerState(status = "Running", displayTime = "10:00", isConnected = true)

        processor.onTimerData(timer)

        assertEquals(timer, sink.updatedTimer)
        assertEquals(timer, sink.persistedTimer)
        assertEquals(1, sink.syncEvents)
        assertEquals(1, sink.markSyncedCalls)
        assertEquals(1, sink.refreshCalls)
    }

    @Test
    fun `tasks sync persists returned tasks and marks sync`() {
        val sink = FakeSink().apply {
            tasksAfterUpdate = listOf(WearTask("id-1", "Task", "E", "1/2"))
        }
        val processor = WearSyncProcessor(sink)

        processor.onTasksData("payload")

        assertEquals("payload", sink.lastTasksJson)
        assertEquals(1, sink.persistedTasks.size)
        assertEquals("id-1", sink.persistedTasks.first().id)
        assertEquals(1, sink.syncEvents)
        assertEquals(1, sink.markSyncedCalls)
        assertEquals(1, sink.refreshCalls)
    }

    @Test
    fun `peer disconnect preserves status and timing but clears connection`() {
        val sink = FakeSink()
        val processor = WearSyncProcessor(sink)
        val running = WearTimerState(
            status = "Running",
            isConnected = true,
            displayTime = "04:00",
            phaseEndEpochMs = 1_709_000_060_000L,
            totalDurationMs = 25L * 60L * 1000L,
        )

        processor.onPeerDisconnected(running)

        assertEquals("Running", sink.updatedTimer?.status)
        assertEquals(false, sink.updatedTimer?.isConnected)
        assertEquals("04:00", sink.updatedTimer?.displayTime)
        assertEquals(1_709_000_060_000L, sink.updatedTimer?.phaseEndEpochMs)
        assertEquals("Running", sink.persistedTimer?.status)
        assertEquals(1, sink.refreshCalls)
        assertTrue(sink.markSyncedCalls == 0)
    }

    private class FakeSink : WearSyncSink {
        var updatedTimer: WearTimerState? = null
        var persistedTimer: WearTimerState? = null
        var lastTasksJson: String? = null
        var tasksAfterUpdate: List<WearTask> = emptyList()
        var persistedTasks: List<WearTask> = emptyList()
        var updatedStats: WearStatsState? = null
        var persistedStats: WearStatsState? = null
        var markSyncedCalls: Int = 0
        var refreshCalls: Int = 0
        var syncEvents: Int = 0

        override fun updateTimer(state: WearTimerState) {
            updatedTimer = state
        }

        override fun persistTimer(state: WearTimerState) {
            persistedTimer = state
        }

        override fun updateTasksFromJson(tasksJson: String): List<WearTask> {
            lastTasksJson = tasksJson
            return tasksAfterUpdate
        }

        override fun persistTasks(tasks: List<WearTask>) {
            persistedTasks = tasks
        }

        override fun updateStats(state: WearStatsState) {
            updatedStats = state
        }

        override fun persistStats(state: WearStatsState) {
            persistedStats = state
        }

        override fun markSyncedNow() {
            markSyncedCalls++
        }

        override fun refreshWearSurfaces() {
            refreshCalls++
        }

        override fun recordSyncEvent() {
            syncEvents++
        }
    }
}
