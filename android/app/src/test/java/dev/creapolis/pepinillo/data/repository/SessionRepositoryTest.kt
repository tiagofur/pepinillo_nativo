package dev.creapolis.pepinillo.data.repository

import dev.creapolis.pepinillo.data.local.dao.DailyStatsDao
import dev.creapolis.pepinillo.data.local.dao.FocusSessionDao
import dev.creapolis.pepinillo.data.local.entity.DailyStatsEntity
import dev.creapolis.pepinillo.data.local.entity.FocusSessionEntity
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flowOf
import org.junit.Assert.assertEquals
import org.junit.After
import org.junit.Before
import org.junit.Test
import java.util.Calendar
import java.util.Locale
import java.util.TimeZone

// ---------------------------------------------------------------------------
// Fake DAOs -- return empty data; only needed so SessionRepository can be
// constructed.  The methods under test (computePeakHours, computeBestDayOfWeek,
// calculateCurrentStreak, calculateBestStreak, startOfDay) are pure functions
// that operate on lists passed directly, so the DAOs are never queried.
// ---------------------------------------------------------------------------

private class FakeFocusSessionDao : FocusSessionDao {
    override suspend fun insertSession(session: FocusSessionEntity) = Unit
    override fun getSessionsForDay(startOfDay: Long): Flow<List<FocusSessionEntity>> = flowOf(emptyList())
    override fun getSessionCountForDay(startOfDay: Long): Flow<Int> = flowOf(0)
    override fun getSessionsInRange(startTime: Long, endTime: Long): Flow<List<FocusSessionEntity>> = flowOf(emptyList())
    override fun getSessionsForTask(taskId: String): Flow<List<FocusSessionEntity>> = flowOf(emptyList())
    override suspend fun getTodayPomodoroWorkCount(startOfDay: Long): Int = 0
    override suspend fun updateJournalEntry(sessionId: String, journalNote: String?, satisfactionRating: Int?, now: Long) = Unit
    override suspend fun getDirtySessions(): List<FocusSessionEntity> = emptyList()
    override suspend fun markSynced(sessionId: String, syncedAt: Long) = Unit
    override suspend fun getSessionsInRangeSync(startTime: Long, endTime: Long): List<FocusSessionEntity> = emptyList()
    override suspend fun getSessionById(sessionId: String): FocusSessionEntity? = null
    override suspend fun insertIfNotExists(session: FocusSessionEntity) = Unit
    override suspend fun upsertSession(session: FocusSessionEntity) = Unit
    override suspend fun upsertSessions(sessions: List<FocusSessionEntity>) = Unit
    override suspend fun getAllSessionsSync(): List<FocusSessionEntity> = emptyList()
    override suspend fun getSessionCount(): Int = 0
    override suspend fun deleteAll() = Unit
    override suspend fun updateLinkedTaskId(sessionId: String, taskId: String) = Unit
    override fun getDirtySessionCount(): Flow<Int> = flowOf(0)
}

private class FakeDailyStatsDao : DailyStatsDao {
    override suspend fun upsert(stats: DailyStatsEntity) = Unit
    override suspend fun getStatsForDate(date: Long): DailyStatsEntity? = null
    override fun observeStatsForDate(date: Long): Flow<DailyStatsEntity?> = flowOf(null)
    override fun getStatsInRange(startDate: Long, endDate: Long): Flow<List<DailyStatsEntity>> = flowOf(emptyList())
    override fun getAllDaysWithSessions(): Flow<List<DailyStatsEntity>> = flowOf(emptyList())
    override suspend fun deleteAll() = Unit
}

class SessionRepositoryTest {

    private lateinit var repo: SessionRepository
    private lateinit var previousLocale: Locale

    private val oneDay = 24 * 60 * 60 * 1000L

    /** Returns the start-of-today millis using the same logic as the repository. */
    private fun today(): Long = SessionRepository.startOfDay(System.currentTimeMillis())

    /** Convenience builder for a DailyStatsEntity at a given epoch-day millis. */
    private fun statsAt(dateMillis: Long, totalMinutes: Int = 25) = DailyStatsEntity(
        date = dateMillis,
        totalMinutes = totalMinutes,
        sessionsCompleted = 1,
    )

    /** Convenience builder for a FocusSessionEntity at a given hour of the day. */
    private fun sessionAt(hour: Int, durationMinutes: Int = 25): FocusSessionEntity {
        val cal = Calendar.getInstance()
        cal.set(Calendar.HOUR_OF_DAY, hour)
        cal.set(Calendar.MINUTE, 0)
        cal.set(Calendar.SECOND, 0)
        cal.set(Calendar.MILLISECOND, 0)
        val start = cal.timeInMillis
        return FocusSessionEntity(
            mode = "Pomodoro",
            startTime = start,
            endTime = start + durationMinutes * 60_000L,
            durationMillis = durationMinutes * 60_000L,
        )
    }

    @Before
    fun setUp() {
        previousLocale = Locale.getDefault()
        Locale.setDefault(Locale.US)
        repo = SessionRepository(
            sessionDao = FakeFocusSessionDao(),
            dailyStatsDao = FakeDailyStatsDao(),
        )
    }

    @After
    fun tearDown() {
        Locale.setDefault(previousLocale)
    }

    // -----------------------------------------------------------------------
    // startOfDay
    // -----------------------------------------------------------------------

    @Test
    fun `startOfDay aligns midnight correctly`() {
        val cal = Calendar.getInstance(TimeZone.getDefault())
        cal.set(2025, Calendar.JUNE, 15, 0, 0, 0)
        cal.set(Calendar.MILLISECOND, 0)
        val midnight = cal.timeInMillis
        assertEquals(midnight, SessionRepository.startOfDay(midnight))
    }

    @Test
    fun `startOfDay truncates afternoon time`() {
        val cal = Calendar.getInstance(TimeZone.getDefault())
        cal.set(2025, Calendar.JUNE, 15, 14, 35, 42)
        cal.set(Calendar.MILLISECOND, 123)
        val result = SessionRepository.startOfDay(cal.timeInMillis)

        val expected = Calendar.getInstance(TimeZone.getDefault())
        expected.set(2025, Calendar.JUNE, 15, 0, 0, 0)
        expected.set(Calendar.MILLISECOND, 0)
        assertEquals(expected.timeInMillis, result)
    }

    @Test
    fun `startOfDay truncates just before midnight`() {
        val cal = Calendar.getInstance(TimeZone.getDefault())
        cal.set(2025, Calendar.JUNE, 15, 23, 59, 59)
        cal.set(Calendar.MILLISECOND, 999)
        val result = SessionRepository.startOfDay(cal.timeInMillis)

        val expected = Calendar.getInstance(TimeZone.getDefault())
        expected.set(2025, Calendar.JUNE, 15, 0, 0, 0)
        expected.set(Calendar.MILLISECOND, 0)
        assertEquals(expected.timeInMillis, result)
    }

    @Test
    fun `startOfDay early morning`() {
        val cal = Calendar.getInstance(TimeZone.getDefault())
        cal.set(2025, Calendar.JANUARY, 1, 3, 15, 0)
        cal.set(Calendar.MILLISECOND, 500)
        val result = SessionRepository.startOfDay(cal.timeInMillis)

        val expected = Calendar.getInstance(TimeZone.getDefault())
        expected.set(2025, Calendar.JANUARY, 1, 0, 0, 0)
        expected.set(Calendar.MILLISECOND, 0)
        assertEquals(expected.timeInMillis, result)
    }

    // -----------------------------------------------------------------------
    // computePeakHours
    // -----------------------------------------------------------------------

    @Test
    fun `computePeakHours returns empty for no sessions`() {
        assertEquals("", repo.computePeakHours(emptyList()))
    }

    @Test
    fun `computePeakHours single session returns its 2-hour window`() {
        val sessions = listOf(sessionAt(hour = 9, durationMinutes = 25))
        val result = repo.computePeakHours(sessions)
        // 9 AM session -> best 2-hour window starts at either 8 or 9.
        // buckets[9]=25, all others 0. Windows: (8,9)=25, (9,10)=25.
        // The loop picks the first one with max sum, starting from h=0.
        // bestStart initialised to 0 with sum buckets[0]+buckets[1]=0,
        // then h=8: sum=0+25=25 > 0 -> bestStart=8,
        // then h=9: sum=25+0=25 == 25, not strictly greater -> bestStart stays 8.
        assertEquals("8 AM\u201310 AM", result)
    }

    @Test
    fun `computePeakHours multiple sessions in same hour`() {
        val sessions = listOf(
            sessionAt(hour = 14, durationMinutes = 25),
            sessionAt(hour = 14, durationMinutes = 30),
        )
        val result = repo.computePeakHours(sessions)
        // buckets[14]=55, rest 0. Windows: (13,14)=55, (14,15)=55.
        // First max at h=13.
        assertEquals("1 PM\u20133 PM", result)
    }

    @Test
    fun `computePeakHours spread across different hours picks best window`() {
        val sessions = listOf(
            sessionAt(hour = 8, durationMinutes = 10),
            sessionAt(hour = 9, durationMinutes = 40),
            sessionAt(hour = 10, durationMinutes = 50),
            sessionAt(hour = 15, durationMinutes = 20),
        )
        val result = repo.computePeakHours(sessions)
        // buckets: [8]=10, [9]=40, [10]=50, [15]=20
        // Windows: (8,9)=50, (9,10)=90, (10,11)=50, (14,15)=20, (15,16)=20
        // Best is h=9 with 90
        assertEquals("9 AM\u201311 AM", result)
    }

    @Test
    fun `computePeakHours session at midnight hour`() {
        val sessions = listOf(sessionAt(hour = 0, durationMinutes = 30))
        val result = repo.computePeakHours(sessions)
        // buckets[0]=30. Initial bestStart=0, bestSum=30+0=30.
        // No other window beats it.
        assertEquals("12 AM\u20132 AM", result)
    }

    @Test
    fun `computePeakHours session at hour 23`() {
        val sessions = listOf(sessionAt(hour = 23, durationMinutes = 30))
        val result = repo.computePeakHours(sessions)
        // buckets[23]=30. The loop checks h=0..22.
        // Window (22,23)=0+30=30. Initial bestStart=0, bestSum=0.
        // h=22: sum=0+30=30 > 0 -> bestStart=22
        // Result: 22 -> "10 PM", (22+2)%24=0 -> "12 AM"
        assertEquals("10 PM\u201312 AM", result)
    }

    @Test
    fun `computePeakHours all zero-duration sessions returns empty`() {
        val sessions = listOf(sessionAt(hour = 10, durationMinutes = 0))
        assertEquals("", repo.computePeakHours(sessions))
    }

    @Test
    fun `computePeakHours noon boundary formatting`() {
        val sessions = listOf(
            sessionAt(hour = 11, durationMinutes = 30),
            sessionAt(hour = 12, durationMinutes = 30),
        )
        val result = repo.computePeakHours(sessions)
        // buckets[11]=30, [12]=30. Window (11,12)=60.
        // 11->"11 AM", 13->"1 PM"
        assertEquals("11 AM\u20131 PM", result)
    }

    // -----------------------------------------------------------------------
    // computeBestDayOfWeek
    // -----------------------------------------------------------------------

    @Test
    fun `computeBestDayOfWeek returns empty for no stats`() {
        assertEquals("", repo.computeBestDayOfWeek(emptyList()))
    }

    @Test
    fun `computeBestDayOfWeek single day returns that day name`() {
        // Build a date that is a known day of the week -- use a Monday
        val cal = Calendar.getInstance()
        cal.set(2025, Calendar.JUNE, 16, 0, 0, 0) // June 16 2025 is a Monday
        cal.set(Calendar.MILLISECOND, 0)
        val stats = listOf(statsAt(cal.timeInMillis, totalMinutes = 60))
        val result = repo.computeBestDayOfWeek(stats)
        assertEquals("Monday", result)
    }

    @Test
    fun `computeBestDayOfWeek picks day with highest total minutes`() {
        val cal = Calendar.getInstance()
        // Monday
        cal.set(2025, Calendar.JUNE, 16, 0, 0, 0)
        cal.set(Calendar.MILLISECOND, 0)
        val monday = cal.timeInMillis
        // Wednesday
        cal.set(2025, Calendar.JUNE, 18, 0, 0, 0)
        cal.set(Calendar.MILLISECOND, 0)
        val wednesday = cal.timeInMillis

        val stats = listOf(
            statsAt(monday, totalMinutes = 30),
            statsAt(wednesday, totalMinutes = 90),
        )
        val result = repo.computeBestDayOfWeek(stats)
        assertEquals("Wednesday", result)
    }

    @Test
    fun `computeBestDayOfWeek aggregates same day of week across weeks`() {
        val cal = Calendar.getInstance()
        // Two Mondays
        cal.set(2025, Calendar.JUNE, 16, 0, 0, 0)
        cal.set(Calendar.MILLISECOND, 0)
        val monday1 = cal.timeInMillis
        cal.set(2025, Calendar.JUNE, 23, 0, 0, 0)
        cal.set(Calendar.MILLISECOND, 0)
        val monday2 = cal.timeInMillis
        // One Friday with a big value
        cal.set(2025, Calendar.JUNE, 20, 0, 0, 0)
        cal.set(Calendar.MILLISECOND, 0)
        val friday = cal.timeInMillis

        val stats = listOf(
            statsAt(monday1, totalMinutes = 40),
            statsAt(monday2, totalMinutes = 50), // Monday total = 90
            statsAt(friday, totalMinutes = 80),   // Friday total = 80
        )
        val result = repo.computeBestDayOfWeek(stats)
        assertEquals("Monday", result)
    }

    @Test
    fun `computeBestDayOfWeek returns empty when all totalMinutes are zero`() {
        val cal = Calendar.getInstance()
        cal.set(2025, Calendar.JUNE, 16, 0, 0, 0)
        cal.set(Calendar.MILLISECOND, 0)
        val stats = listOf(statsAt(cal.timeInMillis, totalMinutes = 0))
        assertEquals("", repo.computeBestDayOfWeek(stats))
    }

    // -----------------------------------------------------------------------
    // calculateCurrentStreak  (actual repository, not copied logic)
    // -----------------------------------------------------------------------

    @Test
    fun `calculateCurrentStreak empty list returns 0`() {
        assertEquals(0, repo.calculateCurrentStreak(emptyList()))
    }

    @Test
    fun `calculateCurrentStreak today only returns 1`() {
        val days = listOf(statsAt(today()))
        assertEquals(1, repo.calculateCurrentStreak(days))
    }

    @Test
    fun `calculateCurrentStreak three consecutive days ending today`() {
        val t = today()
        val days = listOf(
            statsAt(t),
            statsAt(t - oneDay),
            statsAt(t - 2 * oneDay),
        )
        assertEquals(3, repo.calculateCurrentStreak(days))
    }

    @Test
    fun `calculateCurrentStreak gap yesterday breaks streak`() {
        val t = today()
        val days = listOf(
            statsAt(t),
            // yesterday missing
            statsAt(t - 2 * oneDay),
            statsAt(t - 3 * oneDay),
        )
        assertEquals(1, repo.calculateCurrentStreak(days))
    }

    @Test
    fun `calculateCurrentStreak no session today returns 0`() {
        val t = today()
        val days = listOf(
            statsAt(t - oneDay),
            statsAt(t - 2 * oneDay),
        )
        assertEquals(0, repo.calculateCurrentStreak(days))
    }

    @Test
    fun `calculateCurrentStreak handles unordered input`() {
        val t = today()
        val days = listOf(
            statsAt(t - 2 * oneDay),
            statsAt(t),
            statsAt(t - oneDay),
        )
        assertEquals(3, repo.calculateCurrentStreak(days))
    }

    // -----------------------------------------------------------------------
    // calculateBestStreak  (actual repository, not copied logic)
    // -----------------------------------------------------------------------

    @Test
    fun `calculateBestStreak empty list returns 0`() {
        assertEquals(0, repo.calculateBestStreak(emptyList()))
    }

    @Test
    fun `calculateBestStreak single day returns 1`() {
        val days = listOf(statsAt(today()))
        assertEquals(1, repo.calculateBestStreak(days))
    }

    @Test
    fun `calculateBestStreak consecutive days`() {
        val t = today()
        val days = listOf(
            statsAt(t),
            statsAt(t - oneDay),
            statsAt(t - 2 * oneDay),
        )
        assertEquals(3, repo.calculateBestStreak(days))
    }

    @Test
    fun `calculateBestStreak best streak longer than current`() {
        val t = today()
        val days = listOf(
            statsAt(t), // current streak = 1 (gap before)
            // gap
            statsAt(t - 5 * oneDay),
            statsAt(t - 6 * oneDay),
            statsAt(t - 7 * oneDay),
        )
        assertEquals(1, repo.calculateCurrentStreak(days))
        assertEquals(3, repo.calculateBestStreak(days))
    }

    @Test
    fun `calculateBestStreak two separate streaks picks longer`() {
        val t = today()
        val days = listOf(
            // Streak A: 2 days
            statsAt(t),
            statsAt(t - oneDay),
            // gap
            // Streak B: 4 days
            statsAt(t - 10 * oneDay),
            statsAt(t - 11 * oneDay),
            statsAt(t - 12 * oneDay),
            statsAt(t - 13 * oneDay),
        )
        assertEquals(4, repo.calculateBestStreak(days))
    }

    @Test
    fun `calculateBestStreak handles unordered input`() {
        val t = today()
        val days = listOf(
            statsAt(t - 2 * oneDay),
            statsAt(t),
            statsAt(t - oneDay),
        )
        assertEquals(3, repo.calculateBestStreak(days))
    }
}
