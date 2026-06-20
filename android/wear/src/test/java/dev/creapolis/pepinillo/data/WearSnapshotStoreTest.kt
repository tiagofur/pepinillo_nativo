package dev.creapolis.pepinillo.data

import dev.creapolis.pepinillo.testing.FakePreferencesContext
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Verifies that [WearSnapshotStore] actually round-trips the data that [WearViewModel]
 * writes when it persists optimistic updates (C4). Process death must not revert the
 * user's last action on cold restart, so we prove the write/read path is symmetric.
 */
class WearSnapshotStoreTest {

    private val context = FakePreferencesContext()

    @Test
    fun `persistTimerState round-trips every optimistic timer field`() {
        val state = WearTimerState(
            mode = "Flow",
            phase = "ShortBreak",
            status = "Running",
            displayTime = "04:30",
            phaseLabel = "Descanso",
            progress = 0.42f,
            isConnected = true,
            linkedTaskId = "task-7",
            linkedTaskName = "Write design doc",
            completedSessions = 3,
            phaseEndEpochMs = 1_709_000_000_000L,
            totalDurationMs = 25L * 60L * 1000L,
        )

        WearSnapshotStore.persistTimerState(context, state)
        val restored = WearSnapshotStore.readTimerState(context)

        assertEquals(state.mode, restored.mode)
        assertEquals(state.phase, restored.phase)
        assertEquals(state.status, restored.status)
        assertEquals(state.displayTime, restored.displayTime)
        assertEquals(state.phaseLabel, restored.phaseLabel)
        assertEquals(state.progress, restored.progress, 0.0001f)
        assertEquals(state.isConnected, restored.isConnected)
        assertEquals(state.linkedTaskId, restored.linkedTaskId)
        assertEquals(state.linkedTaskName, restored.linkedTaskName)
        assertEquals(state.completedSessions, restored.completedSessions)
        assertEquals(state.phaseEndEpochMs, restored.phaseEndEpochMs)
        assertEquals(state.totalDurationMs, restored.totalDurationMs)
    }

    @Test
    fun `persistTimerState overwrites previous value so stale state cannot survive`() {
        val first = WearTimerState(status = "Running", phaseEndEpochMs = 100L)
        val second = WearTimerState(status = "Idle", phaseEndEpochMs = 0L)

        WearSnapshotStore.persistTimerState(context, first)
        WearSnapshotStore.persistTimerState(context, second)

        val restored = WearSnapshotStore.readTimerState(context)
        assertEquals("Idle", restored.status)
        assertEquals(0L, restored.phaseEndEpochMs)
    }

    @Test
    fun `persistTasks round-trips a multi-task list`() {
        val tasks = listOf(
            WearTask("t-1", "Write report", "HIGH", "1/3"),
            WearTask("t-2", "Review PR with } brace", "MED", "0/2"),
            WearTask("t-3", "Empty progress", "LOW", ""),
        )

        WearSnapshotStore.persistTasks(context, tasks)
        val restored = WearSnapshotStore.readTasks(context)

        assertEquals(tasks, restored)
    }

    @Test
    fun `persistTasks with empty list round-trips cleanly`() {
        WearSnapshotStore.persistTasks(
            context,
            listOf(WearTask("orphan", "Should vanish", "X", "")),
        )

        WearSnapshotStore.persistTasks(context, emptyList())

        assertTrue(WearSnapshotStore.readTasks(context).isEmpty())
    }

    @Test
    fun `persistTasks survives titles containing pipe and newline characters`() {
        // WearSnapshotTaskCodec serialises through Base64-delimited rows, so we want to
        // be sure the codec itself (which the snapshot path uses) is robust.
        val tasks = listOf(
            WearTask("t-1", "Title|with|pipes", "HIGH", "1|3"),
            WearTask("t-2", "Multi\nline\ntitle", "MED", ""),
        )

        WearSnapshotStore.persistTasks(context, tasks)
        val restored = WearSnapshotStore.readTasks(context)

        assertEquals(tasks, restored)
    }

    @Test
    fun `persistIsPro and readIsPro round-trip`() {
        assertFalse(WearSnapshotStore.readIsPro(context))

        WearSnapshotStore.persistIsPro(context, true)
        assertTrue(WearSnapshotStore.readIsPro(context))

        WearSnapshotStore.persistIsPro(context, false)
        assertFalse(WearSnapshotStore.readIsPro(context))
    }

    @Test
    fun `persistLastSyncAtMillis then read returns the same value`() {
        assertNull(WearSnapshotStore.readLastSyncAtMillis(context))

        WearSnapshotStore.persistLastSyncAtMillis(context, 1_700_000_000_000L)
        assertEquals(1_700_000_000_000L, WearSnapshotStore.readLastSyncAtMillis(context))
    }

    @Test
    fun `persistStats round-trips all four counters`() {
        val stats = WearStatsState(
            totalMinutes = 95,
            sessions = 4,
            streak = 6,
            completedTasks = 7,
        )

        WearSnapshotStore.persistStats(context, stats)
        val restored = WearSnapshotStore.readStats(context)

        assertEquals(stats, restored)
    }

    @Test
    fun `persistThemeColors round-trips every colour and theme id`() {
        val colors = WearThemeColors(
            themeId = "ocean",
            pomodoroColor = 0xFFAA1100,
            flowtimeColor = 0xFF00AA11,
            timeBlockColor = 0xFF1100AA,
            stopwatchColor = 0xFFAAAAAA,
            streakColor = 0xFF000000,
        )

        WearSnapshotStore.persistThemeColors(context, colors)
        val restored = WearSnapshotStore.readThemeColors(context)

        assertEquals(colors, restored)
    }
}
