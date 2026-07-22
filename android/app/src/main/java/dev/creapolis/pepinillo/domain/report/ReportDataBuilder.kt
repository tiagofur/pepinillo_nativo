package dev.creapolis.pepinillo.domain.report

import dev.creapolis.pepinillo.data.local.dao.FocusSessionDao
import dev.creapolis.pepinillo.data.local.entity.FocusSessionEntity
import dev.creapolis.pepinillo.data.repository.SessionRepository
import kotlinx.serialization.Serializable
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale
import javax.inject.Inject
import javax.inject.Singleton

@Serializable
data class ReportPayload(
    val period: String,
    val periodStart: String,
    val periodEnd: String,
    val summary: ReportSummary,
    val trends: ReportTrends,
    val patterns: ReportPatterns,
    val taskBreakdown: List<TaskBreakdownEntry>,
    val dailyDistribution: List<DailyDistributionEntry>,
)

@Serializable
data class ReportSummary(
    val totalMinutes: Int,
    val totalSessions: Int,
    val completedSessions: Int,
    val avgSessionMinutes: Int,
    val totalInterruptions: Int,
    val totalPauses: Int,
)

@Serializable
data class ReportTrends(
    val minutesChange: Int,
    val sessionsChange: Int,
    val previousTotalMinutes: Int,
    val previousTotalSessions: Int,
)

@Serializable
data class ReportPatterns(
    val dominantMode: String?,
    val peakHourRange: String,
    val bestDayOfWeek: String,
    val modeDistribution: Map<String, Int>,
)

@Serializable
data class TaskBreakdownEntry(
    val taskId: String,
    val totalMinutes: Int,
    val sessions: Int,
)

@Serializable
data class DailyDistributionEntry(
    val dayLabel: String,
    val minutes: Int,
    val sessions: Int,
)

@Singleton
class ReportDataBuilder @Inject constructor(
    private val sessionDao: FocusSessionDao,
) {
    private val json = Json { ignoreUnknownKeys = true }
    private val isoFormat = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'", Locale.US)

    suspend fun buildPayload(period: String): ReportPayload {
        val cal = Calendar.getInstance()
        val now = System.currentTimeMillis()
        cal.timeInMillis = now

        val todayStart = SessionRepository.startOfDay(now)
        val (periodStart, periodEnd, prevStart, prevEnd) = when (period) {
            "week" -> {
                val end = now
                val start = SessionRepository.addDays(todayStart, -7)
                val prevE = start
                val prevS = SessionRepository.addDays(start, -7)
                PeriodBounds(start, end, prevS, prevE)
            }
            else -> {
                val end = now
                val start = SessionRepository.addDays(todayStart, -30)
                val prevE = start
                val prevS = SessionRepository.addDays(start, -30)
                PeriodBounds(start, end, prevS, prevE)
            }
        }

        val currentSessions = sessionDao.getSessionsInRangeSync(
            SessionRepository.startOfDay(periodStart), periodEnd,
        ).filter { it.phase == null || it.phase == "Work" }

        val previousSessions = sessionDao.getSessionsInRangeSync(
            SessionRepository.startOfDay(prevStart), prevEnd,
        ).filter { it.phase == null || it.phase == "Work" }

        val summary = buildSummary(currentSessions)
        val trends = buildTrends(currentSessions, previousSessions)
        val patterns = buildPatterns(currentSessions)
        val taskBreakdown = buildTaskBreakdown(currentSessions)
        val dailyDistribution = buildDailyDistribution(currentSessions, periodStart, periodEnd, period)

        return ReportPayload(
            period = period,
            periodStart = isoFormat.format(periodStart),
            periodEnd = isoFormat.format(periodEnd),
            summary = summary,
            trends = trends,
            patterns = patterns,
            taskBreakdown = taskBreakdown,
            dailyDistribution = dailyDistribution,
        )
    }

    fun toJsonString(payload: ReportPayload): String = json.encodeToString(payload)

    private fun buildSummary(sessions: List<FocusSessionEntity>): ReportSummary {
        val totalMillis = sessions.sumOf { it.durationMillis }
        val totalMinutes = (totalMillis / 60_000).toInt()
        val totalSessions = sessions.size
        val completed = sessions.count { it.wasCompleted }
        val avgMinutes = if (totalSessions > 0) totalMinutes / totalSessions else 0
        val interruptions = sessions.sumOf { it.interruptions }
        val pauses = sessions.sumOf { it.pauseCount }

        return ReportSummary(
            totalMinutes = totalMinutes,
            totalSessions = totalSessions,
            completedSessions = completed,
            avgSessionMinutes = avgMinutes,
            totalInterruptions = interruptions,
            totalPauses = pauses,
        )
    }

    private fun buildTrends(
        current: List<FocusSessionEntity>,
        previous: List<FocusSessionEntity>,
    ): ReportTrends {
        val currentMinutes = (current.sumOf { it.durationMillis } / 60_000).toInt()
        val previousMinutes = (previous.sumOf { it.durationMillis } / 60_000).toInt()

        return ReportTrends(
            minutesChange = currentMinutes - previousMinutes,
            sessionsChange = current.size - previous.size,
            previousTotalMinutes = previousMinutes,
            previousTotalSessions = previous.size,
        )
    }

    private fun buildPatterns(sessions: List<FocusSessionEntity>): ReportPatterns {
        val byMode = sessions.groupBy { it.mode }
        val modeMinutes = byMode.mapValues { (_, s) -> (s.sumOf { it.durationMillis } / 60_000).toInt() }
        val dominant = modeMinutes.maxByOrNull { it.value }?.key

        val cal = Calendar.getInstance()
        // Peak hours
        val hourBuckets = IntArray(24)
        for (s in sessions) {
            cal.timeInMillis = s.startTime
            hourBuckets[cal.get(Calendar.HOUR_OF_DAY)] += (s.durationMillis / 60_000).toInt()
        }
        var bestStart = 0
        var bestSum = hourBuckets[0] + hourBuckets.getOrElse(1) { 0 }
        for (h in 1 until 23) {
            val sum = hourBuckets[h] + hourBuckets[h + 1]
            if (sum > bestSum) { bestSum = sum; bestStart = h }
        }
        val peakRange = if (bestSum > 0) {
            val fmt = { h: Int -> when { h == 0 -> "12 AM"; h < 12 -> "$h AM"; h == 12 -> "12 PM"; else -> "${h - 12} PM" } }
            "${fmt(bestStart)}\u2013${fmt((bestStart + 2) % 24)}"
        } else ""

        // Best day
        val dayBuckets = IntArray(7)
        val dayFormat = SimpleDateFormat("EEEE", Locale.getDefault())
        for (s in sessions) {
            cal.timeInMillis = s.startTime
            dayBuckets[cal.get(Calendar.DAY_OF_WEEK) - 1] += (s.durationMillis / 60_000).toInt()
        }
        val bestDayIdx = dayBuckets.indices.maxByOrNull { dayBuckets[it] } ?: 0
        val bestDay = if (dayBuckets[bestDayIdx] > 0) {
            cal.set(Calendar.DAY_OF_WEEK, bestDayIdx + 1)
            dayFormat.format(cal.time)
        } else ""

        return ReportPatterns(
            dominantMode = dominant,
            peakHourRange = peakRange,
            bestDayOfWeek = bestDay,
            modeDistribution = modeMinutes,
        )
    }

    private fun buildTaskBreakdown(sessions: List<FocusSessionEntity>): List<TaskBreakdownEntry> {
        val byTask = sessions.filter { it.linkedTaskId != null }.groupBy { it.linkedTaskId!! }
        return byTask.map { (taskId, taskSessions) ->
            TaskBreakdownEntry(
                taskId = taskId,
                totalMinutes = (taskSessions.sumOf { it.durationMillis } / 60_000).toInt(),
                sessions = taskSessions.size,
            )
        }.sortedByDescending { it.totalMinutes }
    }

    private fun buildDailyDistribution(
        sessions: List<FocusSessionEntity>,
        periodStart: Long,
        periodEnd: Long,
        period: String,
    ): List<DailyDistributionEntry> {
        val cal = Calendar.getInstance()
        val dayFormat = if (period == "week") SimpleDateFormat("EEE", Locale.getDefault())
        else SimpleDateFormat("d", Locale.getDefault())

        val days = if (period == "week") 7 else 30
        return (days - 1 downTo 0).map { daysAgo ->
            cal.timeInMillis = System.currentTimeMillis()
            cal.add(Calendar.DAY_OF_YEAR, -daysAgo)
            cal.set(Calendar.HOUR_OF_DAY, 0); cal.set(Calendar.MINUTE, 0)
            cal.set(Calendar.SECOND, 0); cal.set(Calendar.MILLISECOND, 0)
            val dayStart = cal.timeInMillis
            val dayEnd = SessionRepository.addDays(dayStart, 1)

            val daySessions = sessions.filter { it.startTime >= dayStart && it.startTime < dayEnd }
            DailyDistributionEntry(
                dayLabel = dayFormat.format(cal.time),
                minutes = (daySessions.sumOf { it.durationMillis } / 60_000).toInt(),
                sessions = daySessions.size,
            )
        }
    }

    private data class PeriodBounds(
        val periodStart: Long,
        val periodEnd: Long,
        val prevStart: Long,
        val prevEnd: Long,
    )
}
