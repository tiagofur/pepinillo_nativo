package dev.creapolis.pepinillo.data.repository

import dev.creapolis.pepinillo.data.local.dao.DailyStatsDao
import dev.creapolis.pepinillo.data.local.dao.FocusSessionDao
import dev.creapolis.pepinillo.data.local.entity.DailyStatsEntity
import dev.creapolis.pepinillo.data.local.entity.FocusSessionEntity
import kotlinx.coroutines.flow.Flow
import java.util.Calendar
import java.util.TimeZone
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class SessionRepository @Inject constructor(
    private val sessionDao: FocusSessionDao,
    private val dailyStatsDao: DailyStatsDao,
) {
    suspend fun recordSession(
        mode: String,
        startTime: Long,
        endTime: Long,
        durationMillis: Long,
        linkedTaskId: String? = null,
        phase: String? = null,
    ) {
        // Insert the session
        sessionDao.insertSession(
            FocusSessionEntity(
                mode = mode,
                startTime = startTime,
                endTime = endTime,
                durationMillis = durationMillis,
                linkedTaskId = linkedTaskId,
                phase = phase,
            ),
        )

        // Update daily stats
        val today = startOfDay(System.currentTimeMillis())
        val minutes = (durationMillis / 60_000).toInt()
        val existing = dailyStatsDao.getStatsForDate(today) ?: DailyStatsEntity(date = today)

        dailyStatsDao.upsert(
            existing.copy(
                totalMinutes = existing.totalMinutes + minutes,
                sessionsCompleted = existing.sessionsCompleted + 1,
                longestSessionMinutes = maxOf(existing.longestSessionMinutes, minutes),
                pomodoroMinutes = existing.pomodoroMinutes + if (mode == "Pomodoro") minutes else 0,
                flowMinutes = existing.flowMinutes + if (mode == "Flow") minutes else 0,
                blocksMinutes = existing.blocksMinutes + if (mode == "Blocks") minutes else 0,
                stopwatchMinutes = existing.stopwatchMinutes + if (mode == "Chrono") minutes else 0,
            ),
        )
    }

    fun getTodaySessions(): Flow<List<FocusSessionEntity>> =
        sessionDao.getSessionsForDay(startOfDay(System.currentTimeMillis()))

    fun getTodaySessionCount(): Flow<Int> =
        sessionDao.getSessionCountForDay(startOfDay(System.currentTimeMillis()))

    fun getTodayStats(): Flow<DailyStatsEntity?> =
        dailyStatsDao.observeStatsForDate(startOfDay(System.currentTimeMillis()))

    fun getWeekStats(): Flow<List<DailyStatsEntity>> {
        val now = System.currentTimeMillis()
        val weekAgo = now - 7L * 24 * 60 * 60 * 1000
        return dailyStatsDao.getStatsInRange(startOfDay(weekAgo), startOfDay(now))
    }

    fun getAllDaysWithSessions(): Flow<List<DailyStatsEntity>> =
        dailyStatsDao.getAllDaysWithSessions()

    companion object {
        fun startOfDay(millis: Long): Long {
            val cal = Calendar.getInstance(TimeZone.getDefault())
            cal.timeInMillis = millis
            cal.set(Calendar.HOUR_OF_DAY, 0)
            cal.set(Calendar.MINUTE, 0)
            cal.set(Calendar.SECOND, 0)
            cal.set(Calendar.MILLISECOND, 0)
            return cal.timeInMillis
        }
    }
}
