package dev.creapolis.pepinillo.data.repository

import dev.creapolis.pepinillo.data.local.dao.DailyStatsDao
import dev.creapolis.pepinillo.data.local.dao.FocusSessionDao
import dev.creapolis.pepinillo.data.local.entity.DailyStatsEntity
import dev.creapolis.pepinillo.data.local.entity.FocusSessionEntity
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.util.Calendar
import java.util.TimeZone

class SessionDateRangeDstTest {

    @Test
    fun `addDays handles spring forward DST transition preserving midnight local time`() {
        val tz = TimeZone.getTimeZone("America/New_York")
        // In 2026, spring forward in US Eastern is March 8 at 2 AM
        val cal = Calendar.getInstance(tz)
        cal.set(2026, Calendar.MARCH, 8, 0, 0, 0)
        cal.set(Calendar.MILLISECOND, 0)
        val springDayStart = cal.timeInMillis

        // Adding 1 day via addDays using default/NY timezone
        val tzDefault = TimeZone.getDefault()
        try {
            TimeZone.setDefault(tz)

            val nextDayStart = SessionRepository.addDays(springDayStart, 1)

            val checkCal = Calendar.getInstance(tz)
            checkCal.timeInMillis = nextDayStart
            assertEquals(2026, checkCal.get(Calendar.YEAR))
            assertEquals(Calendar.MARCH, checkCal.get(Calendar.MONTH))
            assertEquals(9, checkCal.get(Calendar.DAY_OF_MONTH))
            assertEquals(0, checkCal.get(Calendar.HOUR_OF_DAY))
            assertEquals(0, checkCal.get(Calendar.MINUTE))
            assertEquals(0, checkCal.get(Calendar.SECOND))

            // Spring forward day has 23 hours = 23 * 3,600,000 ms = 82,800,000 ms
            assertEquals(82_800_000L, nextDayStart - springDayStart)
        } finally {
            TimeZone.setDefault(tzDefault)
        }
    }

    @Test
    fun `addDays handles fall back DST transition preserving midnight local time`() {
        val tz = TimeZone.getTimeZone("America/New_York")
        // In 2026, fall back in US Eastern is Nov 1 at 2 AM
        val cal = Calendar.getInstance(tz)
        cal.set(2026, Calendar.NOVEMBER, 1, 0, 0, 0)
        cal.set(Calendar.MILLISECOND, 0)
        val fallDayStart = cal.timeInMillis

        val tzDefault = TimeZone.getDefault()
        try {
            TimeZone.setDefault(tz)

            val nextDayStart = SessionRepository.addDays(fallDayStart, 1)

            val checkCal = Calendar.getInstance(tz)
            checkCal.timeInMillis = nextDayStart
            assertEquals(2026, checkCal.get(Calendar.YEAR))
            assertEquals(Calendar.NOVEMBER, checkCal.get(Calendar.MONTH))
            assertEquals(2, checkCal.get(Calendar.DAY_OF_MONTH))
            assertEquals(0, checkCal.get(Calendar.HOUR_OF_DAY))
            assertEquals(0, checkCal.get(Calendar.MINUTE))
            assertEquals(0, checkCal.get(Calendar.SECOND))

            // Fall back day has 25 hours = 25 * 3,600,000 ms = 90,000,000 ms
            assertEquals(90_000_000L, nextDayStart - fallDayStart)
        } finally {
            TimeZone.setDefault(tzDefault)
        }
    }

    @Test
    fun `getTodaySessions queries with startOfDay and addDays(1) upper bound`() = runTest {
        var queriedStart: Long? = null
        var queriedEnd: Long? = null

        val mockSessionDao = object : FocusSessionDao {
            override fun getSessionsForDay(startOfDay: Long, endOfDay: Long): Flow<List<FocusSessionEntity>> {
                queriedStart = startOfDay
                queriedEnd = endOfDay
                return flowOf(emptyList())
            }

            override fun getSessionCountForDay(startOfDay: Long, endOfDay: Long): Flow<Int> = flowOf(0)
            override fun getSessionsInRange(startTime: Long, endTime: Long): Flow<List<FocusSessionEntity>> = flowOf(emptyList())
            override fun getSessionsForTask(taskId: String): Flow<List<FocusSessionEntity>> = flowOf(emptyList())
            override suspend fun getTodayPomodoroWorkCount(startOfDay: Long, endOfDay: Long): Int = 0
            override suspend fun updateJournalEntry(sessionId: String, journalNote: String?, satisfactionRating: Int?, now: Long) = Unit
            override suspend fun getDirtySessions(): List<FocusSessionEntity> = emptyList()
            override suspend fun markSynced(sessionId: String, syncedAt: Long) = Unit
            override suspend fun getSessionsInRangeSync(startTime: Long, endTime: Long): List<FocusSessionEntity> = emptyList()
            override suspend fun getSessionById(sessionId: String): FocusSessionEntity? = null
            override suspend fun insertSession(session: FocusSessionEntity) = Unit
            override suspend fun insertIfNotExists(session: FocusSessionEntity) = Unit
            override suspend fun upsertSession(session: FocusSessionEntity) = Unit
            override suspend fun upsertSessions(sessions: List<FocusSessionEntity>) = Unit
            override suspend fun getAllSessionsSync(): List<FocusSessionEntity> = emptyList()
            override suspend fun getSessionCount(): Int = 0
            override suspend fun deleteAll() = Unit
            override suspend fun updateLinkedTaskId(sessionId: String, taskId: String) = Unit
            override fun getDirtySessionCount(): Flow<Int> = flowOf(0)
        }

        val mockDailyStatsDao = object : DailyStatsDao {
            override suspend fun upsert(stats: DailyStatsEntity) = Unit
            override suspend fun getStatsForDate(date: Long): DailyStatsEntity? = null
            override fun observeStatsForDate(date: Long): Flow<DailyStatsEntity?> = flowOf(null)
            override fun getStatsInRange(startDate: Long, endDate: Long): Flow<List<DailyStatsEntity>> = flowOf(emptyList())
            override fun getAllDaysWithSessions(): Flow<List<DailyStatsEntity>> = flowOf(emptyList())
            override suspend fun deleteAll() = Unit
            override suspend fun getDirtyStats(): List<DailyStatsEntity> = emptyList()
            override suspend fun markSynced(date: Long, syncedAt: Long) = Unit
        }

        val repo = SessionRepository(mockSessionDao, mockDailyStatsDao)
        repo.getTodaySessions().first()

        val expectedStart = SessionRepository.startOfDay(System.currentTimeMillis())
        val expectedEnd = SessionRepository.addDays(expectedStart, 1)

        assertEquals(expectedStart, queriedStart)
        assertEquals(expectedEnd, queriedEnd)
        assertTrue(queriedEnd!! > queriedStart!!)
    }
}
