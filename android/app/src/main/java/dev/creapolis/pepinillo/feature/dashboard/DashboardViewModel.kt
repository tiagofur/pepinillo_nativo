package dev.creapolis.pepinillo.feature.dashboard

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import dagger.hilt.android.lifecycle.HiltViewModel
import dev.creapolis.pepinillo.data.local.entity.DailyStatsEntity
import dev.creapolis.pepinillo.data.local.entity.FocusSessionEntity
import dev.creapolis.pepinillo.data.repository.SessionRepository
import dev.creapolis.pepinillo.feature.dashboard.model.Achievement
import dev.creapolis.pepinillo.feature.dashboard.model.AnalyticsPeriod
import dev.creapolis.pepinillo.feature.dashboard.model.DailyFocus
import dev.creapolis.pepinillo.feature.dashboard.model.DashboardStats
import dev.creapolis.pepinillo.feature.dashboard.model.ModeUsage
import dev.creapolis.pepinillo.feature.dashboard.model.WeeklyReportData
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.flatMapLatest
import kotlinx.coroutines.flow.stateIn
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale
import javax.inject.Inject

@OptIn(ExperimentalCoroutinesApi::class)
@HiltViewModel
class DashboardViewModel @Inject constructor(
    private val sessionRepository: SessionRepository,
) : ViewModel() {

    private val _selectedPeriod = MutableStateFlow(AnalyticsPeriod.Week)

    private val _showWeeklyReview = MutableStateFlow(false)
    val showWeeklyReview: StateFlow<Boolean> = _showWeeklyReview.asStateFlow()

    val stats: StateFlow<DashboardStats> = _selectedPeriod.flatMapLatest { period ->
        combine(
            sessionRepository.getTodayStats(),
            getStatsForPeriod(period),
            sessionRepository.getAllDaysWithSessions(),
            sessionRepository.getTodaySessions(),
        ) { todayStats, periodStats, allDays, todaySessions ->
            buildStats(todayStats, periodStats, allDays, todaySessions, period)
        }
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), DashboardStats())

    val weeklyReport: StateFlow<WeeklyReportData> = combine(
        sessionRepository.getWeekStats(),
        sessionRepository.getPreviousWeekStats(),
        sessionRepository.getAllDaysWithSessions(),
    ) { currentWeek, previousWeek, allDays ->
        buildWeeklyReport(currentWeek, previousWeek, allDays)
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), WeeklyReportData())

    fun setPeriod(period: AnalyticsPeriod) {
        _selectedPeriod.value = period
    }

    fun showWeeklyReview() {
        _showWeeklyReview.value = true
    }

    fun dismissWeeklyReview() {
        _showWeeklyReview.value = false
    }

    private fun getStatsForPeriod(period: AnalyticsPeriod) = when (period) {
        AnalyticsPeriod.Week -> sessionRepository.getWeekStats()
        AnalyticsPeriod.Month -> sessionRepository.getMonthStats()
        AnalyticsPeriod.Year -> sessionRepository.getYearStats()
    }

    private fun buildStats(
        today: DailyStatsEntity?,
        periodStats: List<DailyStatsEntity>,
        allDays: List<DailyStatsEntity>,
        todaySessions: List<FocusSessionEntity>,
        period: AnalyticsPeriod,
    ): DashboardStats {
        val todayMinutes = today?.totalMinutes ?: 0
        val todaySess = today?.sessionsCompleted ?: 0
        val periodMinutes = periodStats.sumOf { it.totalMinutes }
        val periodSessions = periodStats.sumOf { it.sessionsCompleted }
        val streak = sessionRepository.calculateCurrentStreak(allDays)
        val bestStreak = sessionRepository.calculateBestStreak(allDays)

        // Chart data
        val chartData = buildChartData(periodStats, period)

        // Mode breakdown
        val modeBreakdown = buildModeBreakdown(periodStats)

        // Productivity patterns
        val peakHours = sessionRepository.computePeakHours(todaySessions)
        val bestDay = sessionRepository.computeBestDayOfWeek(periodStats)
        val focusScore = computeFocusScore(periodStats)

        // Achievements
        val achievements = computeAchievements(allDays, streak)

        return DashboardStats(
            todayMinutes = todayMinutes,
            todaySessions = todaySess,
            weekMinutes = if (period == AnalyticsPeriod.Week) periodMinutes else 0,
            weekSessions = if (period == AnalyticsPeriod.Week) periodSessions else 0,
            currentStreak = streak,
            bestStreak = bestStreak,
            longestSessionMinutes = periodStats.maxOfOrNull { it.longestSessionMinutes } ?: 0,
            weeklyData = if (period == AnalyticsPeriod.Week) chartData else emptyList(),
            modeBreakdown = modeBreakdown,
            isLoading = false,
            selectedPeriod = period,
            periodMinutes = periodMinutes,
            periodSessions = periodSessions,
            chartData = chartData,
            peakHourRange = peakHours,
            bestDayOfWeek = bestDay,
            focusScore = focusScore,
            achievements = achievements,
        )
    }

    private fun buildChartData(stats: List<DailyStatsEntity>, period: AnalyticsPeriod): List<DailyFocus> {
        val cal = Calendar.getInstance()
        return when (period) {
            AnalyticsPeriod.Week -> {
                val dayFormat = SimpleDateFormat("EEE", Locale.getDefault())
                (6 downTo 0).map { daysAgo ->
                    cal.time = Date()
                    cal.add(Calendar.DAY_OF_YEAR, -daysAgo)
                    cal.set(Calendar.HOUR_OF_DAY, 0); cal.set(Calendar.MINUTE, 0)
                    cal.set(Calendar.SECOND, 0); cal.set(Calendar.MILLISECOND, 0)
                    val dayStart = cal.timeInMillis
                    val dayLabel = dayFormat.format(cal.time)
                    DailyFocus(dayLabel, stats.find { it.date == dayStart }?.totalMinutes ?: 0)
                }
            }
            AnalyticsPeriod.Month -> {
                (29 downTo 0).map { daysAgo ->
                    cal.time = Date()
                    cal.add(Calendar.DAY_OF_YEAR, -daysAgo)
                    cal.set(Calendar.HOUR_OF_DAY, 0); cal.set(Calendar.MINUTE, 0)
                    cal.set(Calendar.SECOND, 0); cal.set(Calendar.MILLISECOND, 0)
                    val dayStart = cal.timeInMillis
                    val dayLabel = "${cal.get(Calendar.DAY_OF_MONTH)}"
                    DailyFocus(dayLabel, stats.find { it.date == dayStart }?.totalMinutes ?: 0)
                }
            }
            AnalyticsPeriod.Year -> {
                val monthFormat = SimpleDateFormat("MMM", Locale.getDefault())
                (11 downTo 0).map { monthsAgo ->
                    cal.time = Date()
                    cal.add(Calendar.MONTH, -monthsAgo)
                    cal.set(Calendar.DAY_OF_MONTH, 1)
                    cal.set(Calendar.HOUR_OF_DAY, 0); cal.set(Calendar.MINUTE, 0)
                    cal.set(Calendar.SECOND, 0); cal.set(Calendar.MILLISECOND, 0)
                    val monthStart = cal.timeInMillis
                    val monthLabel = monthFormat.format(cal.time)
                    val nextMonth = cal.clone() as Calendar
                    nextMonth.add(Calendar.MONTH, 1)
                    val monthMinutes = stats
                        .filter { it.date >= monthStart && it.date < nextMonth.timeInMillis }
                        .sumOf { it.totalMinutes }
                    DailyFocus(monthLabel, monthMinutes)
                }
            }
        }
    }

    private fun buildModeBreakdown(stats: List<DailyStatsEntity>): List<ModeUsage> {
        val total = stats.sumOf {
            it.pomodoroMinutes + it.flowMinutes + it.blocksMinutes + it.stopwatchMinutes
        }.coerceAtLeast(1)
        val pomodoroMin = stats.sumOf { it.pomodoroMinutes }
        val flowMin = stats.sumOf { it.flowMinutes }
        val blocksMin = stats.sumOf { it.blocksMinutes }
        val stopwatchMin = stats.sumOf { it.stopwatchMinutes }

        return listOf(
            ModeUsage("Pomodoro", 0, pomodoroMin, pomodoroMin.toFloat() / total),
            ModeUsage("Flow", 0, flowMin, flowMin.toFloat() / total),
            ModeUsage("Blocks", 0, blocksMin, blocksMin.toFloat() / total),
            ModeUsage("Chrono", 0, stopwatchMin, stopwatchMin.toFloat() / total),
        ).filter { it.totalMinutes > 0 }
    }

    private fun computeFocusScore(stats: List<DailyStatsEntity>): Int {
        if (stats.isEmpty()) return 0
        val daysWithActivity = stats.count { it.sessionsCompleted > 0 }
        val totalDays = stats.size.coerceAtLeast(1)
        val consistencyRate = daysWithActivity.toFloat() / totalDays
        val avgMinutes = stats.sumOf { it.totalMinutes }.toFloat() / totalDays
        val minuteScore = (avgMinutes / 60f).coerceAtMost(1f) // 60 min/day = perfect
        return ((consistencyRate * 60 + minuteScore * 40)).toInt().coerceIn(0, 100)
    }

    private fun computeAchievements(
        allDays: List<DailyStatsEntity>,
        currentStreak: Int,
    ): List<Achievement> {
        val totalSessions = allDays.sumOf { it.sessionsCompleted }
        val totalPomodoro = allDays.sumOf { it.pomodoroMinutes }
        val totalFlow = allDays.sumOf { it.flowMinutes }
        val pomodoroSessions = allDays.count { it.pomodoroMinutes > 0 }
        val flowSessions = allDays.count { it.flowMinutes > 0 }

        return listOf(
            Achievement(
                id = "first_focus", title = "First Focus", icon = "\uD83C\uDFAF",
                isUnlocked = totalSessions >= 1,
                progress = (totalSessions.coerceAtMost(1) / 1f),
                progressText = "${totalSessions.coerceAtMost(1)}/1",
            ),
            Achievement(
                id = "week_warrior", title = "Week Warrior", icon = "\uD83D\uDD25",
                isUnlocked = currentStreak >= 7,
                progress = (currentStreak.coerceAtMost(7) / 7f),
                progressText = "${currentStreak.coerceAtMost(7)}/7",
            ),
            Achievement(
                id = "pomodoro_master", title = "Pomodoro Master", icon = "\uD83C\uDF36\uFE0F",
                isUnlocked = pomodoroSessions >= 100,
                progress = (pomodoroSessions.coerceAtMost(100) / 100f),
                progressText = "${pomodoroSessions.coerceAtMost(100)}/100",
            ),
            Achievement(
                id = "deep_diver", title = "Deep Diver", icon = "\uD83E\uDD3F",
                isUnlocked = flowSessions >= 10,
                progress = (flowSessions.coerceAtMost(10) / 10f),
                progressText = "${flowSessions.coerceAtMost(10)}/10",
            ),
            Achievement(
                id = "century_club", title = "Century Club", icon = "\uD83D\uDCAF",
                isUnlocked = totalSessions >= 100,
                progress = (totalSessions.coerceAtMost(100) / 100f),
                progressText = "${totalSessions.coerceAtMost(100)}/100",
            ),
        )
    }

    private fun buildWeeklyReport(
        currentWeek: List<DailyStatsEntity>,
        previousWeek: List<DailyStatsEntity>,
        allDays: List<DailyStatsEntity>,
    ): WeeklyReportData {
        val currentMinutes = currentWeek.sumOf { it.totalMinutes }
        val currentSessions = currentWeek.sumOf { it.sessionsCompleted }
        val previousMinutes = previousWeek.sumOf { it.totalMinutes }
        val previousSessions = previousWeek.sumOf { it.sessionsCompleted }
        val streak = sessionRepository.calculateCurrentStreak(allDays)

        // Dominant mode
        val pomodoroMin = currentWeek.sumOf { it.pomodoroMinutes }
        val flowMin = currentWeek.sumOf { it.flowMinutes }
        val blocksMin = currentWeek.sumOf { it.blocksMinutes }
        val stopwatchMin = currentWeek.sumOf { it.stopwatchMinutes }
        val modeMap = mapOf("Pomodoro" to pomodoroMin, "Flow" to flowMin, "Blocks" to blocksMin, "Chrono" to stopwatchMin)
        val dominant = modeMap.maxByOrNull { it.value }?.takeIf { it.value > 0 }?.key

        // Best day
        val dayFormat = SimpleDateFormat("EEEE", Locale.getDefault())
        val cal = Calendar.getInstance()
        val bestDay = currentWeek.maxByOrNull { it.totalMinutes }
        val bestDayName = bestDay?.let {
            cal.timeInMillis = it.date
            dayFormat.format(cal.time)
        }

        // Mode distribution
        val totalMode = (pomodoroMin + flowMin + blocksMin + stopwatchMin).coerceAtLeast(1)
        val distribution = listOf(
            ModeUsage("Pomodoro", 0, pomodoroMin, pomodoroMin.toFloat() / totalMode),
            ModeUsage("Flow", 0, flowMin, flowMin.toFloat() / totalMode),
            ModeUsage("Blocks", 0, blocksMin, blocksMin.toFloat() / totalMode),
            ModeUsage("Chrono", 0, stopwatchMin, stopwatchMin.toFloat() / totalMode),
        ).filter { it.totalMinutes > 0 }

        // Weekly chart
        val chartDayFormat = SimpleDateFormat("EEE", Locale.getDefault())
        val weeklyChart = (6 downTo 0).map { daysAgo ->
            cal.time = Date()
            cal.add(Calendar.DAY_OF_YEAR, -daysAgo)
            cal.set(Calendar.HOUR_OF_DAY, 0); cal.set(Calendar.MINUTE, 0)
            cal.set(Calendar.SECOND, 0); cal.set(Calendar.MILLISECOND, 0)
            val dayStart = cal.timeInMillis
            DailyFocus(chartDayFormat.format(cal.time), currentWeek.find { it.date == dayStart }?.totalMinutes ?: 0)
        }

        return WeeklyReportData(
            currentWeekMinutes = currentMinutes,
            currentWeekSessions = currentSessions,
            previousWeekMinutes = previousMinutes,
            previousWeekSessions = previousSessions,
            dominantMode = dominant,
            bestDayName = bestDayName,
            bestDayMinutes = bestDay?.totalMinutes ?: 0,
            currentStreak = streak,
            modeDistribution = distribution,
            weeklyChartData = weeklyChart,
        )
    }
}
