package dev.creapolis.pepinillo.data.repository

import android.util.Log
import dev.creapolis.pepinillo.data.local.PepinilloDatabase
import dev.creapolis.pepinillo.data.local.dao.DailyStatsDao
import dev.creapolis.pepinillo.data.local.dao.FocusSessionDao
import dev.creapolis.pepinillo.data.local.entity.DailyStatsEntity
import dev.creapolis.pepinillo.data.local.entity.FocusSessionEntity
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.catch
import kotlinx.coroutines.flow.flatMapLatest
import kotlinx.coroutines.flow.map
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale
import java.util.TimeZone
import javax.inject.Inject
import javax.inject.Singleton

data class TaskAnalytics(
    val taskId: String,
    val taskTitle: String,
    val totalSessions: Int,
    val completedSessions: Int,
    val totalFocusMinutes: Int,
    val avgSessionMinutes: Int,
    val totalInterruptions: Int,
    val avgInterruptionsPerSession: Double,
    val totalPauses: Int,
    val avgSatisfactionRating: Double?,
    val modeDistribution: Map<String, Int>,
    val peakHourBucket: Int?,
    val estimatedPomodoros: Int,
    val completedPomodoros: Int,
    val estimationAccuracy: Double?,
)

private const val TAG = "SessionRepository"

@Singleton
class SessionRepository @Inject constructor(
    private val sessionDao: FocusSessionDao,
    private val dailyStatsDao: DailyStatsDao,
    private val database: PepinilloDatabase? = null,
) {
    private val _currentDayStart = MutableStateFlow(startOfDay(System.currentTimeMillis()))

    /** Called by FocusEngine when the calendar day changes — refreshes all "today" flows. */
    fun notifyDayChanged() {
        _currentDayStart.value = startOfDay(System.currentTimeMillis())
    }

    suspend fun recordSession(
        mode: String,
        startTime: Long,
        endTime: Long,
        durationMillis: Long,
        linkedTaskId: String? = null,
        phase: String? = null,
        wasCompleted: Boolean = true,
        interruptions: Int = 0,
        pauseCount: Int = 0,
        totalPauseMillis: Long = 0,
        pomodoroNumber: Int? = null,
        journalNote: String? = null,
        satisfactionRating: Int? = null,
        targetDurationMillis: Long? = null,
    ): String? {
        if (durationMillis <= 0 || startTime <= 0 || endTime <= startTime) return null
        val sessionId = java.util.UUID.randomUUID().toString()
        val now = System.currentTimeMillis()
        runCatching {
            val sessionEntity = FocusSessionEntity(
                id = sessionId,
                mode = mode,
                startTime = startTime,
                endTime = endTime,
                durationMillis = durationMillis,
                linkedTaskId = linkedTaskId,
                phase = phase,
                createdAt = now,
                updatedAt = now,
                wasCompleted = wasCompleted,
                interruptions = interruptions,
                pauseCount = pauseCount,
                totalPauseMillis = totalPauseMillis,
                pomodoroNumber = pomodoroNumber,
                journalNote = journalNote,
                satisfactionRating = satisfactionRating,
                targetDurationMillis = targetDurationMillis,
            )

            // Only update daily summary stats for completed work sessions (not breaks)
            val isBreakPhase = phase == "ShortBreak" || phase == "LongBreak"
            val updatedStats = if (!isBreakPhase) {
                val sessionDay = startOfDay(startTime)
                val minutes = ((durationMillis + 30_000) / 60_000).toInt() // round instead of truncate
                val existing = dailyStatsDao.getStatsForDate(sessionDay) ?: DailyStatsEntity(date = sessionDay)

                existing.copy(
                    totalMinutes = existing.totalMinutes + minutes,
                    // Only count completed work sessions toward the "sessions completed" tally
                    sessionsCompleted = existing.sessionsCompleted + if (wasCompleted) 1 else 0,
                    longestSessionMinutes = maxOf(existing.longestSessionMinutes, minutes),
                    pomodoroMinutes = existing.pomodoroMinutes + if (mode == "Pomodoro") minutes else 0,
                    flowMinutes = existing.flowMinutes + if (mode == "Flow") minutes else 0,
                    blocksMinutes = existing.blocksMinutes + if (mode == "Blocks") minutes else 0,
                    stopwatchMinutes = existing.stopwatchMinutes + if (mode == "Chrono") minutes else 0,
                    isDirty = true,
                )
            } else null

            if (database != null) {
                database.recordSessionAtomic(sessionEntity, updatedStats)
            } else {
                sessionDao.insertSession(sessionEntity)
                updatedStats?.let { dailyStatsDao.upsert(it) }
            }
        }.onFailure { Log.e(TAG, "Error recording session", it); return null }
        return sessionId
    }

    suspend fun saveJournalEntry(sessionId: String, note: String?, rating: Int?) {
        runCatching {
            sessionDao.updateJournalEntry(sessionId, note, rating, System.currentTimeMillis())
        }.onFailure { Log.e(TAG, "Error saving journal entry", it) }
    }

    /** Count today's completed Pomodoro work sessions (for long break calculation). */
    suspend fun getTodayPomodoroWorkCount(): Int =
        runCatching {
            val start = startOfDay(System.currentTimeMillis())
            val end = addDays(start, 1)
            sessionDao.getTodayPomodoroWorkCount(start, end)
        }
            .onFailure { Log.e(TAG, "Error counting today's pomodoro work sessions", it) }
            .getOrDefault(0)

    fun getTodaySessions(): Flow<List<FocusSessionEntity>> =
        _currentDayStart.flatMapLatest { dayStart ->
            val dayEnd = addDays(dayStart, 1)
            sessionDao.getSessionsForDay(dayStart, dayEnd)
                .catch { e -> Log.e(TAG, "Error loading today sessions", e); emit(emptyList()) }
        }

    fun getTodaySessionCount(): Flow<Int> =
        _currentDayStart.flatMapLatest { dayStart ->
            val dayEnd = addDays(dayStart, 1)
            sessionDao.getSessionCountForDay(dayStart, dayEnd)
                .catch { e -> Log.e(TAG, "Error loading session count", e); emit(0) }
        }

    fun getTodayStats(): Flow<DailyStatsEntity?> =
        _currentDayStart.flatMapLatest { dayStart ->
            dailyStatsDao.observeStatsForDate(dayStart)
                .catch { e -> Log.e(TAG, "Error loading today stats", e); emit(null) }
        }

    fun getWeekStats(): Flow<List<DailyStatsEntity>> =
        _currentDayStart.flatMapLatest { todayStart ->
            // 7-day window: [today - 6 days .. today], matching the chart's (6 downTo 0) range.
            // getStatsInRange uses >= startDate AND <= endDate (both inclusive).
            val weekStart = addDays(todayStart, -6)
            dailyStatsDao.getStatsInRange(weekStart, todayStart)
                .catch { e -> Log.e(TAG, "Error loading week stats", e); emit(emptyList()) }
        }

    fun getMonthStats(): Flow<List<DailyStatsEntity>> =
        _currentDayStart.flatMapLatest { todayStart ->
            // 30-day window: [today - 29 days .. today], consistent with getMonthSessions.
            val monthStart = addDays(todayStart, -29)
            dailyStatsDao.getStatsInRange(monthStart, todayStart)
                .catch { e -> Log.e(TAG, "Error loading month stats", e); emit(emptyList()) }
        }

    fun getYearStats(): Flow<List<DailyStatsEntity>> =
        _currentDayStart.flatMapLatest { todayStart ->
            // 364-day window: [today - 363 days .. today].
            val yearStart = addDays(todayStart, -363)
            dailyStatsDao.getStatsInRange(yearStart, todayStart)
                .catch { e -> Log.e(TAG, "Error loading year stats", e); emit(emptyList()) }
        }

    fun getPreviousWeekStats(): Flow<List<DailyStatsEntity>> =
        _currentDayStart.flatMapLatest { todayStart ->
            // Previous 7-day window: [today - 13 days .. today - 7 days].
            val twoWeeksStart = addDays(todayStart, -13)
            val weekAgoStart = addDays(todayStart, -7)
            dailyStatsDao.getStatsInRange(twoWeeksStart, weekAgoStart)
                .catch { e -> Log.e(TAG, "Error loading previous week stats", e); emit(emptyList()) }
        }

    fun getStatsForMonth(year: Int, month: Int): Flow<List<DailyStatsEntity>> {
        val cal = Calendar.getInstance()
        cal.set(year, month, 1, 0, 0, 0)
        cal.set(Calendar.MILLISECOND, 0)
        val start = cal.timeInMillis
        cal.add(Calendar.MONTH, 1)
        // getStatsInRange's upper bound is inclusive (date <= end) and day keys are exact
        // midnights — keep the bound inside the requested month so the next month's first
        // day is not pulled in.
        val end = cal.timeInMillis - 1
        return dailyStatsDao.getStatsInRange(start, end)
            .catch { e -> Log.e(TAG, "Error loading month stats", e); emit(emptyList()) }
    }

    fun getWeekSessions(): Flow<List<FocusSessionEntity>> =
        _currentDayStart.flatMapLatest { todayStart ->
            // Same 7-day window as getWeekStats. getSessionsInRange uses exclusive upper bound,
            // so add one full day to include all sessions that started today.
            val weekStart = addDays(todayStart, -6)
            val tomorrowStart = addDays(todayStart, 1)
            sessionDao.getSessionsInRange(weekStart, tomorrowStart)
                .catch { e -> Log.e(TAG, "Error loading week sessions", e); emit(emptyList()) }
        }

    fun getMonthSessions(): Flow<List<FocusSessionEntity>> =
        _currentDayStart.flatMapLatest { todayStart ->
            // Same 30-day window as getMonthStats.
            val monthStart = addDays(todayStart, -29)
            val tomorrowStart = addDays(todayStart, 1)
            sessionDao.getSessionsInRange(monthStart, tomorrowStart)
                .catch { e -> Log.e(TAG, "Error loading month sessions", e); emit(emptyList()) }
        }

    fun getYearSessions(): Flow<List<FocusSessionEntity>> =
        _currentDayStart.flatMapLatest { todayStart ->
            // Same 364-day window as getYearStats.
            val yearStart = addDays(todayStart, -363)
            val tomorrowStart = addDays(todayStart, 1)
            sessionDao.getSessionsInRange(yearStart, tomorrowStart)
                .catch { e -> Log.e(TAG, "Error loading year sessions", e); emit(emptyList()) }
        }

    fun getPreviousWeekSessions(): Flow<List<FocusSessionEntity>> =
        _currentDayStart.flatMapLatest { todayStart ->
            // Same previous-week window as getPreviousWeekStats: [today-13 .. today-7].
            // getSessionsInRange uses exclusive upper bound, so add one full day to include all
            // sessions that started on today-7 (mirroring the current-week alignment).
            val twoWeeksStart = addDays(todayStart, -13)
            val weekAgoEnd = addDays(todayStart, -6) // exclusive: day after today-7
            sessionDao.getSessionsInRange(twoWeeksStart, weekAgoEnd)
                .catch { e -> Log.e(TAG, "Error loading previous week sessions", e); emit(emptyList()) }
        }

    fun getPreviousMonthSessions(): Flow<List<FocusSessionEntity>> =
        _currentDayStart.flatMapLatest { todayStart ->
            // Same previous-month window as getPreviousMonthStats: [today-59 .. today-30].
            // getSessionsInRange uses exclusive upper bound, so today-29 as exclusive upper means
            // the last fully-included day is today-30 (no overlap with current month's today-29).
            val twoMonthsStart = addDays(todayStart, -59)
            val monthAgoEnd = addDays(todayStart, -29) // exclusive: day after today-30
            sessionDao.getSessionsInRange(twoMonthsStart, monthAgoEnd)
                .catch { e -> Log.e(TAG, "Error loading previous month sessions", e); emit(emptyList()) }
        }

    fun getPreviousMonthStats(): Flow<List<DailyStatsEntity>> =
        _currentDayStart.flatMapLatest { todayStart ->
            // Previous month window: [today-59 .. today-30], matching getPreviousMonthSessions.
            val twoMonthsStart = addDays(todayStart, -59)
            val monthAgoStart = addDays(todayStart, -30)
            dailyStatsDao.getStatsInRange(twoMonthsStart, monthAgoStart)
                .catch { e -> Log.e(TAG, "Error loading previous month stats", e); emit(emptyList()) }
        }

    fun getSessionsForDate(dateMillis: Long): Flow<List<FocusSessionEntity>> {
        val startOfDay = startOfDay(dateMillis)
        val endOfDay = addDays(startOfDay, 1)
        return sessionDao.getSessionsInRange(startOfDay, endOfDay)
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
        // Find best 2-hour window — windows may wrap midnight ((23, 0) is valid)
        var bestStart = 0
        var bestSum = -1
        for (h in 0 until 24) {
            val sum = hourBuckets[h] + hourBuckets[(h + 1) % 24]
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

    fun getTaskAnalytics(
        taskId: String,
        taskTitle: String,
        estimatedPomodoros: Int,
        completedPomodoros: Int,
    ): Flow<TaskAnalytics> =
        sessionDao.getSessionsForTask(taskId)
            .map { sessions ->
                val workSessions = sessions.filter { it.phase == null || it.phase == "Work" }
                val totalFocusMinutes = workSessions.sumOf { (it.durationMillis / 60_000).toInt() }
                val totalSessions = workSessions.size
                val completedSessions = workSessions.count { it.wasCompleted }
                val avgSessionMinutes = if (totalSessions > 0) totalFocusMinutes / totalSessions else 0
                val totalInterruptions = workSessions.sumOf { it.interruptions }
                val avgInterruptionsPerSession = if (totalSessions > 0) {
                    totalInterruptions.toDouble() / totalSessions
                } else 0.0
                val totalPauses = workSessions.sumOf { it.pauseCount }

                val ratings = workSessions.mapNotNull { it.satisfactionRating }
                val avgSatisfactionRating = if (ratings.isNotEmpty()) {
                    ratings.average()
                } else null

                // Mode distribution: mode name → total minutes
                val modeDistribution = workSessions
                    .groupBy { it.mode }
                    .mapValues { (_, modeSessions) ->
                        modeSessions.sumOf { (it.durationMillis / 60_000).toInt() }
                    }

                // Peak hour bucket: hour with most focus minutes
                val peakHourBucket = if (workSessions.isNotEmpty()) {
                    val hourBuckets = IntArray(24)
                    val cal = Calendar.getInstance()
                    for (s in workSessions) {
                        cal.timeInMillis = s.startTime
                        val hour = cal.get(Calendar.HOUR_OF_DAY)
                        hourBuckets[hour] += (s.durationMillis / 60_000).toInt()
                    }
                    val maxMinutes = hourBuckets.max()
                    if (maxMinutes > 0) hourBuckets.indexOfFirst { it == maxMinutes } else null
                } else null

                val estimationAccuracy = if (estimatedPomodoros > 0 && completedPomodoros > 0) {
                    completedPomodoros.toDouble() / estimatedPomodoros
                } else null

                TaskAnalytics(
                    taskId = taskId,
                    taskTitle = taskTitle,
                    totalSessions = totalSessions,
                    completedSessions = completedSessions,
                    totalFocusMinutes = totalFocusMinutes,
                    avgSessionMinutes = avgSessionMinutes,
                    totalInterruptions = totalInterruptions,
                    avgInterruptionsPerSession = avgInterruptionsPerSession,
                    totalPauses = totalPauses,
                    avgSatisfactionRating = avgSatisfactionRating,
                    modeDistribution = modeDistribution,
                    peakHourBucket = peakHourBucket,
                    estimatedPomodoros = estimatedPomodoros,
                    completedPomodoros = completedPomodoros,
                    estimationAccuracy = estimationAccuracy,
                )
            }
            .catch { e -> Log.e(TAG, "Error computing task analytics for $taskId", e) }

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

        fun addDays(startOfDayMillis: Long, days: Int): Long {
            val cal = Calendar.getInstance(TimeZone.getDefault())
            cal.timeInMillis = startOfDayMillis
            cal.set(Calendar.HOUR_OF_DAY, 0)
            cal.set(Calendar.MINUTE, 0)
            cal.set(Calendar.SECOND, 0)
            cal.set(Calendar.MILLISECOND, 0)
            cal.add(Calendar.DAY_OF_YEAR, days)
            return cal.timeInMillis
        }
    }
}
