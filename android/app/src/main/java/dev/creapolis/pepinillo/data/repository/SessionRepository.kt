package dev.creapolis.pepinillo.data.repository

import android.util.Log
import dev.creapolis.pepinillo.data.local.dao.DailyStatsDao
import dev.creapolis.pepinillo.data.local.dao.FocusSessionDao
import dev.creapolis.pepinillo.data.local.entity.DailyStatsEntity
import dev.creapolis.pepinillo.data.local.entity.FocusSessionEntity
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.catch
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale
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

            // Only update daily summary stats for work sessions (not breaks)
            val isBreakPhase = phase == "ShortBreak" || phase == "LongBreak"
            if (!isBreakPhase) {
                val today = startOfDay(System.currentTimeMillis())
                val minutes = ((durationMillis + 30_000) / 60_000).toInt() // round instead of truncate
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

    fun getMonthStats(): Flow<List<DailyStatsEntity>> {
        val now = System.currentTimeMillis()
        val monthAgo = now - 30L * 24 * 60 * 60 * 1000
        return dailyStatsDao.getStatsInRange(startOfDay(monthAgo), startOfDay(now))
            .catch { e -> Log.e(TAG, "Error loading month stats", e); emit(emptyList()) }
    }

    fun getYearStats(): Flow<List<DailyStatsEntity>> {
        val now = System.currentTimeMillis()
        val yearAgo = now - 364L * 24 * 60 * 60 * 1000
        return dailyStatsDao.getStatsInRange(startOfDay(yearAgo), startOfDay(now))
            .catch { e -> Log.e(TAG, "Error loading year stats", e); emit(emptyList()) }
    }

    fun getPreviousWeekStats(): Flow<List<DailyStatsEntity>> {
        val now = System.currentTimeMillis()
        val twoWeeksAgo = now - 14L * 24 * 60 * 60 * 1000
        val weekAgo = now - 7L * 24 * 60 * 60 * 1000
        return dailyStatsDao.getStatsInRange(startOfDay(twoWeeksAgo), startOfDay(weekAgo))
            .catch { e -> Log.e(TAG, "Error loading previous week stats", e); emit(emptyList()) }
    }

    fun getStatsForMonth(year: Int, month: Int): Flow<List<DailyStatsEntity>> {
        val cal = Calendar.getInstance()
        cal.set(year, month, 1, 0, 0, 0)
        cal.set(Calendar.MILLISECOND, 0)
        val start = cal.timeInMillis
        cal.add(Calendar.MONTH, 1)
        val end = cal.timeInMillis
        return dailyStatsDao.getStatsInRange(start, end)
            .catch { e -> Log.e(TAG, "Error loading month stats", e); emit(emptyList()) }
    }

    fun getWeekSessions(): Flow<List<FocusSessionEntity>> {
        val now = System.currentTimeMillis()
        val weekAgo = now - 7L * 24 * 60 * 60 * 1000
        return sessionDao.getSessionsInRange(startOfDay(weekAgo), now)
            .catch { e -> Log.e(TAG, "Error loading week sessions", e); emit(emptyList()) }
    }

    fun getMonthSessions(): Flow<List<FocusSessionEntity>> {
        val now = System.currentTimeMillis()
        val monthAgo = now - 30L * 24 * 60 * 60 * 1000
        return sessionDao.getSessionsInRange(startOfDay(monthAgo), now)
            .catch { e -> Log.e(TAG, "Error loading month sessions", e); emit(emptyList()) }
    }

    fun getYearSessions(): Flow<List<FocusSessionEntity>> {
        val now = System.currentTimeMillis()
        val yearAgo = now - 364L * 24 * 60 * 60 * 1000
        return sessionDao.getSessionsInRange(startOfDay(yearAgo), now)
            .catch { e -> Log.e(TAG, "Error loading year sessions", e); emit(emptyList()) }
    }

    fun getPreviousWeekSessions(): Flow<List<FocusSessionEntity>> {
        val now = System.currentTimeMillis()
        val twoWeeksAgo = now - 14L * 24 * 60 * 60 * 1000
        val weekAgo = now - 7L * 24 * 60 * 60 * 1000
        return sessionDao.getSessionsInRange(startOfDay(twoWeeksAgo), startOfDay(weekAgo))
            .catch { e -> Log.e(TAG, "Error loading previous week sessions", e); emit(emptyList()) }
    }

    fun getSessionsForDate(dateMillis: Long): Flow<List<FocusSessionEntity>> {
        val endOfDay = dateMillis + 24 * 60 * 60 * 1000
        return sessionDao.getSessionsInRange(dateMillis, endOfDay)
            .catch { e -> Log.e(TAG, "Error loading sessions for date", e); emit(emptyList()) }
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

    fun computePeakHours(sessions: List<FocusSessionEntity>): String {
        if (sessions.isEmpty()) return ""
        val hourBuckets = IntArray(24)
        val cal = Calendar.getInstance()
        for (s in sessions) {
            cal.timeInMillis = s.startTime
            val hour = cal.get(Calendar.HOUR_OF_DAY)
            hourBuckets[hour] += (s.durationMillis / 60_000).toInt()
        }
        // Find best 2-hour window
        var bestStart = 0
        var bestSum = hourBuckets[0] + hourBuckets[1]
        for (h in 1 until 23) {
            val sum = hourBuckets[h] + hourBuckets[h + 1]
            if (sum > bestSum) {
                bestSum = sum
                bestStart = h
            }
        }
        if (bestSum == 0) return ""
        val fmt = { h: Int ->
            when {
                h == 0 -> "12 AM"
                h < 12 -> "$h AM"
                h == 12 -> "12 PM"
                else -> "${h - 12} PM"
            }
        }
        return "${fmt(bestStart)}\u2013${fmt((bestStart + 2) % 24)}"
    }

    fun computeBestDayOfWeek(stats: List<DailyStatsEntity>): String {
        if (stats.isEmpty()) return ""
        val dayTotals = IntArray(7)
        val cal = Calendar.getInstance()
        val dayFormat = SimpleDateFormat("EEEE", Locale.getDefault())
        for (s in stats) {
            cal.timeInMillis = s.date
            val dow = cal.get(Calendar.DAY_OF_WEEK) - 1 // 0=Sun
            dayTotals[dow] += s.totalMinutes
        }
        val bestIndex = dayTotals.indices.maxByOrNull { dayTotals[it] } ?: return ""
        if (dayTotals[bestIndex] == 0) return ""
        cal.set(Calendar.DAY_OF_WEEK, bestIndex + 1)
        return dayFormat.format(cal.time)
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
