package dev.creapolis.pepinillo.data.repository

import android.util.Log
import dev.creapolis.pepinillo.data.local.dao.DailyStatsDao
import dev.creapolis.pepinillo.data.local.dao.FocusSessionDao
import dev.creapolis.pepinillo.data.local.entity.DailyStatsEntity
import dev.creapolis.pepinillo.data.local.entity.FocusSessionEntity
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.catch
import kotlinx.coroutines.flow.emptyFlow
import java.util.Calendar
import java.util.TimeZone
import javax.inject.Inject
import javax.inject.Singleton

private const val TAG = "SessionRepository"

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
        if (durationMillis <= 0 || startTime <= 0 || endTime <= startTime) return
        runCatching {
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
        }.onFailure { Log.e(TAG, "Error recording session", it) }
    }

    fun getTodaySessions(): Flow<List<FocusSessionEntity>> =
        sessionDao.getSessionsForDay(startOfDay(System.currentTimeMillis()))
            .catch { e -> Log.e(TAG, "Error loading today sessions", e); emit(emptyList()) }

    fun getTodaySessionCount(): Flow<Int> =
        sessionDao.getSessionCountForDay(startOfDay(System.currentTimeMillis()))
            .catch { e -> Log.e(TAG, "Error loading session count", e); emit(0) }

    fun getTodayStats(): Flow<DailyStatsEntity?> =
        dailyStatsDao.observeStatsForDate(startOfDay(System.currentTimeMillis()))
            .catch { e -> Log.e(TAG, "Error loading today stats", e); emit(null) }

    fun getWeekStats(): Flow<List<DailyStatsEntity>> {
        val now = System.currentTimeMillis()
        val weekAgo = now - 7L * 24 * 60 * 60 * 1000
        return dailyStatsDao.getStatsInRange(startOfDay(weekAgo), startOfDay(now))
            .catch { e -> Log.e(TAG, "Error loading week stats", e); emit(emptyList()) }
    }

    fun getAllDaysWithSessions(): Flow<List<DailyStatsEntity>> =
        dailyStatsDao.getAllDaysWithSessions()
            .catch { e -> Log.e(TAG, "Error loading all days", e); emit(emptyList()) }

    fun calculateCurrentStreak(allDays: List<DailyStatsEntity>): Int {
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
                cal.add(Calendar.DAY_OF_YEAR, -1)
                expected = cal.timeInMillis
            } else if (date < expected) {
                break
            }
        }
        return streak
    }

    fun calculateBestStreak(allDays: List<DailyStatsEntity>): Int {
        if (allDays.isEmpty()) return 0
        val sortedDates = allDays.map { it.date }.sorted()
        var best = 1
        var current = 1
        val cal = Calendar.getInstance()
        for (i in 1 until sortedDates.size) {
            cal.timeInMillis = sortedDates[i - 1]
            cal.add(Calendar.DAY_OF_YEAR, 1)
            if (sortedDates[i] == cal.timeInMillis) {
                current++
                best = maxOf(best, current)
            } else {
                current = 1
            }
        }
        return best
    }

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
