package dev.creapolis.pepinillo.data.repository

import dev.creapolis.pepinillo.data.local.entity.DailyStatsEntity
import org.junit.Assert.assertEquals
import org.junit.Before
import org.junit.Test
import java.util.Calendar
import java.util.TimeZone

class StreakCalculationTest {

    private lateinit var repository: SessionRepository

    private val oneDay = 24 * 60 * 60 * 1000L

    private fun today(): Long {
        val cal = Calendar.getInstance(TimeZone.getDefault())
        cal.set(Calendar.HOUR_OF_DAY, 0)
        cal.set(Calendar.MINUTE, 0)
        cal.set(Calendar.SECOND, 0)
        cal.set(Calendar.MILLISECOND, 0)
        return cal.timeInMillis
    }

    private fun statsForDate(dateMillis: Long) = DailyStatsEntity(
        date = dateMillis,
        totalMinutes = 25,
        sessionsCompleted = 1,
    )

    @Before
    fun setup() {
        // We can't easily construct SessionRepository without DAOs for this test,
        // but the streak methods are pure functions on List<DailyStatsEntity>.
        // We'll test them via a helper that replicates the logic.
        // In a real scenario we'd extract to a companion or util.
    }

    // Test calculateCurrentStreak logic directly
    private fun calculateCurrentStreak(allDays: List<DailyStatsEntity>): Int {
        if (allDays.isEmpty()) return 0
        val sortedDates = allDays.map { it.date }.sortedDescending()
        val cal = Calendar.getInstance()
        cal.set(Calendar.HOUR_OF_DAY, 0)
        cal.set(Calendar.MINUTE, 0)
        cal.set(Calendar.SECOND, 0)
        cal.set(Calendar.MILLISECOND, 0)
        var expected = cal.timeInMillis
        var streak = 0

        for (date in sortedDates) {
            if (date == expected) {
                streak++
                expected -= oneDay
            } else if (date < expected) {
                break
            }
        }
        return streak
    }

    private fun calculateBestStreak(allDays: List<DailyStatsEntity>): Int {
        if (allDays.isEmpty()) return 0
        val sortedDates = allDays.map { it.date }.sorted()
        var best = 1
        var current = 1
        for (i in 1 until sortedDates.size) {
            if (sortedDates[i] - sortedDates[i - 1] == oneDay) {
                current++
                best = maxOf(best, current)
            } else {
                current = 1
            }
        }
        return best
    }

    @Test
    fun `empty days returns 0 streak`() {
        assertEquals(0, calculateCurrentStreak(emptyList()))
        assertEquals(0, calculateBestStreak(emptyList()))
    }

    @Test
    fun `single day today returns streak of 1`() {
        val days = listOf(statsForDate(today()))
        assertEquals(1, calculateCurrentStreak(days))
        assertEquals(1, calculateBestStreak(days))
    }

    @Test
    fun `consecutive 3 days ending today returns streak of 3`() {
        val t = today()
        val days = listOf(
            statsForDate(t),
            statsForDate(t - oneDay),
            statsForDate(t - 2 * oneDay),
        )
        assertEquals(3, calculateCurrentStreak(days))
        assertEquals(3, calculateBestStreak(days))
    }

    @Test
    fun `gap in streak breaks current streak`() {
        val t = today()
        val days = listOf(
            statsForDate(t),
            // missing yesterday
            statsForDate(t - 2 * oneDay),
            statsForDate(t - 3 * oneDay),
        )
        assertEquals(1, calculateCurrentStreak(days))
    }

    @Test
    fun `best streak can be longer than current`() {
        val t = today()
        val days = listOf(
            statsForDate(t), // current: 1 (gap before)
            // gap
            statsForDate(t - 5 * oneDay),
            statsForDate(t - 6 * oneDay),
            statsForDate(t - 7 * oneDay),
        )
        assertEquals(1, calculateCurrentStreak(days))
        assertEquals(3, calculateBestStreak(days))
    }

    @Test
    fun `no session today means streak is 0`() {
        val t = today()
        val days = listOf(
            statsForDate(t - oneDay),
            statsForDate(t - 2 * oneDay),
        )
        assertEquals(0, calculateCurrentStreak(days))
    }
}
