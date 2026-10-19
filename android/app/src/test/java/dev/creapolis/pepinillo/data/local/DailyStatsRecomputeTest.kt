package dev.creapolis.pepinillo.data.local

import dev.creapolis.pepinillo.data.local.entity.FocusSessionEntity
import dev.creapolis.pepinillo.data.local.entity.TaskEntity
import java.util.Calendar
import java.util.TimeZone
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class DailyStatsRecomputeTest {

    private fun dayStart(millis: Long, zone: TimeZone = TimeZone.getDefault()): Long {
        val cal = Calendar.getInstance(zone).apply {
            timeInMillis = millis
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }
        return cal.timeInMillis
    }

    private fun session(
        id: String = "s",
        mode: String = "Pomodoro",
        phase: String? = "Work",
        day: Long,
        minutes: Int,
        wasCompleted: Boolean = true,
    ) = FocusSessionEntity(
        id = id,
        mode = mode,
        startTime = day + 9 * 3_600_000L,
        endTime = day + 9 * 3_600_000L + minutes * 60_000L,
        durationMillis = minutes * 60_000L,
        phase = phase,
        wasCompleted = wasCompleted,
    )

    @Test
    fun `recompute credits a completed pomodoro to its start day`() {
        val day = dayStart(1_767_312_000_000L) // 2026-01-02 UTC
        val rows = recomputeDailyStats(
            sessions = listOf(session(day = day, minutes = 25)),
            tasks = emptyList(),
            now = day + 3_600_000L,
        )

        assertEquals(1, rows.size)
        val row = rows.single()
        assertEquals(day, row.date)
        assertEquals(25, row.totalMinutes)
        assertEquals(1, row.sessionsCompleted)
        assertEquals(25, row.pomodoroMinutes)
        assertEquals(25, row.longestSessionMinutes)
        assertEquals(0, row.tasksCompleted)
    }

    @Test
    fun `recompute skips break phases and zero-length sessions`() {
        val day = dayStart(1_767_312_000_000L)
        val rows = recomputeDailyStats(
            sessions = listOf(
                session(id = "b", phase = "ShortBreak", day = day, minutes = 5),
                session(id = "z", day = day, minutes = 0),
            ),
            tasks = emptyList(),
            now = day + 3_600_000L,
        )

        assertTrue(rows.isEmpty())
    }

    @Test
    fun `recompute keeps minutes but not completion for abandoned sessions`() {
        val day = dayStart(1_767_312_000_000L)
        val rows = recomputeDailyStats(
            sessions = listOf(session(day = day, minutes = 12, wasCompleted = false)),
            tasks = emptyList(),
            now = day + 3_600_000L,
        )

        assertEquals(12, rows.single().totalMinutes)
        assertEquals(0, rows.single().sessionsCompleted)
    }

    @Test
    fun `recompute buckets minutes per mode`() {
        val day = dayStart(1_767_312_000_000L)
        val rows = recomputeDailyStats(
            sessions = listOf(
                session(id = "f", mode = "Flow", day = day, minutes = 40),
                session(id = "c", mode = "Chrono", day = day, minutes = 10),
                session(id = "b", mode = "Blocks", day = day, minutes = 30),
            ),
            tasks = emptyList(),
            now = day + 3_600_000L,
        )

        val row = rows.single()
        assertEquals(40, row.flowMinutes)
        assertEquals(10, row.stopwatchMinutes)
        assertEquals(30, row.blocksMinutes)
        assertEquals(0, row.pomodoroMinutes)
        assertEquals(80, row.totalMinutes)
    }

    @Test
    fun `recompute derives tasksCompleted from completed and recurring occurrences`() {
        val day = dayStart(1_767_312_000_000L)
        val rows = recomputeDailyStats(
            sessions = emptyList(),
            tasks = listOf(
                TaskEntity(id = "t1", title = "done", isCompleted = true, completedAt = day + 3_600_000L),
                TaskEntity(id = "t2", title = "rec", lastCompletedAt = day + 7_200_000L),
                TaskEntity(id = "t3", title = "old", isCompleted = true, completedAt = day - 3_600_000L),
            ),
            now = day + 3_600_000L,
        )

        val today = rows.single { it.date == day }
        assertEquals(2, today.tasksCompleted)
        // The previous-day completion lands on its own row.
        assertEquals(1, rows.single { it.date == dayStart(day - 3_600_000L) }.tasksCompleted)
    }

    @Test
    fun `normalizeLegacyDueDate converts UTC midnight to local midnight in UTC-3`() {
        val zone = TimeZone.getTimeZone("America/Argentina/Buenos_Aires")
        // 2026-03-05T00:00:00Z — picker wrote UTC midnight for local date Mar 5.
        val raw = 1_772_668_800_000L
        val expected = Calendar.getInstance(zone).apply {
            clear()
            set(2026, Calendar.MARCH, 5, 0, 0, 0)
        }.timeInMillis

        assertEquals(expected, normalizeLegacyDueDate(raw, zone))
    }

    @Test
    fun `normalizeLegacyDueDate is a no-op in UTC`() {
        val zone = TimeZone.getTimeZone("UTC")
        val raw = 1_772_668_800_000L

        assertEquals(raw, normalizeLegacyDueDate(raw, zone))
    }

    @Test
    fun `normalizeLegacyDueDate converts UTC midnight to local midnight in UTC+5-30`() {
        val zone = TimeZone.getTimeZone("Asia/Kolkata")
        val raw = 1_772_668_800_000L
        val expected = Calendar.getInstance(zone).apply {
            clear()
            set(2026, Calendar.MARCH, 5, 0, 0, 0)
        }.timeInMillis

        assertEquals(expected, normalizeLegacyDueDate(raw, zone))
    }

    @Test
    fun `normalizeLegacyDueDate leaves non-UTC-midnight values untouched`() {
        val zone = TimeZone.getTimeZone("America/Argentina/Buenos_Aires")
        // Local midnight Mar 5 in UTC-3 = 03:00Z — must not be reinterpreted.
        val localMidnight = 1_772_679_600_000L

        assertEquals(localMidnight, normalizeLegacyDueDate(localMidnight, zone))
    }
}
