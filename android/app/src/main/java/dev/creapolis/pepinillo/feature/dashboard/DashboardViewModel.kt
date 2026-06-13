package dev.creapolis.pepinillo.feature.dashboard

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import dagger.hilt.android.lifecycle.HiltViewModel
import dev.creapolis.pepinillo.core.billing.FeatureGate
import dev.creapolis.pepinillo.data.local.entity.DailyStatsEntity
import dev.creapolis.pepinillo.domain.streak.StreakProtectionService
import dev.creapolis.pepinillo.data.local.entity.FocusSessionEntity
import dev.creapolis.pepinillo.data.repository.SessionRepository
import dev.creapolis.pepinillo.data.repository.TaskRepository
import dev.creapolis.pepinillo.feature.dashboard.model.Achievement
import dev.creapolis.pepinillo.feature.dashboard.model.AnalyticsPeriod
import dev.creapolis.pepinillo.feature.dashboard.model.DailyFocus
import dev.creapolis.pepinillo.feature.dashboard.model.DashboardStats
import dev.creapolis.pepinillo.feature.dashboard.model.ModeUsage
import dev.creapolis.pepinillo.feature.dashboard.model.MonthlyReportData
import dev.creapolis.pepinillo.feature.dashboard.model.ReflectionPreviews
import dev.creapolis.pepinillo.feature.dashboard.model.TopTaskUsage
import dev.creapolis.pepinillo.feature.dashboard.model.WeeklyReportData
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.launch
import kotlinx.coroutines.flow.Flow
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
    private val taskRepository: TaskRepository,
    private val featureGate: FeatureGate,
) : ViewModel() {

    val hasLocalPremium: StateFlow<Boolean> = featureGate.subscriptionState.let { flow ->
        kotlinx.coroutines.flow.MutableStateFlow(flow.value.hasLocalPremium).also { mutable ->
            viewModelScope.launch {
                flow.collect { mutable.value = it.hasLocalPremium }
            }
        }
    }

    val canUseAI: StateFlow<Boolean> = featureGate.subscriptionState.let { flow ->
        kotlinx.coroutines.flow.MutableStateFlow(flow.value.canSync).also { mutable ->
            viewModelScope.launch {
                flow.collect { mutable.value = it.canSync }
            }
        }
    }

    private val _selectedPeriod = MutableStateFlow(AnalyticsPeriod.Week)

    private val _showWeeklyReview = MutableStateFlow(false)
    val showWeeklyReview: StateFlow<Boolean> = _showWeeklyReview.asStateFlow()

    private val _showMonthlyReview = MutableStateFlow(false)
    val showMonthlyReview: StateFlow<Boolean> = _showMonthlyReview.asStateFlow()

    private val _isRefreshing = MutableStateFlow(false)
    val isRefreshing: StateFlow<Boolean> = _isRefreshing.asStateFlow()

    val stats: StateFlow<DashboardStats> = _selectedPeriod.flatMapLatest { period ->
        combine(
            sessionRepository.getTodayStats(),
            getStatsForPeriod(period),
            sessionRepository.getAllDaysWithSessions(),
            getSessionsForPeriod(period),
        ) { todayStats, periodStats, allDays, periodSessions ->
            buildStats(todayStats, periodStats, allDays, periodSessions, period)
        }
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), DashboardStats())

    val weeklyReport: StateFlow<WeeklyReportData> = combine(
        sessionRepository.getWeekSessions(),
        sessionRepository.getPreviousWeekSessions(),
        sessionRepository.getWeekStats(),
        sessionRepository.getAllDaysWithSessions(),
    ) { currentWeekSessions, previousWeekSessions, currentWeekStats, allDays ->
        buildWeeklyReport(currentWeekSessions, previousWeekSessions, currentWeekStats, allDays)
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), WeeklyReportData())

    val monthlyReport: StateFlow<MonthlyReportData> = combine(
        sessionRepository.getMonthSessions(),
        sessionRepository.getPreviousMonthSessions(),
        sessionRepository.getMonthStats(),
        sessionRepository.getAllDaysWithSessions(),
    ) { currentMonthSessions, previousMonthSessions, currentMonthStats, _ ->
        buildMonthlyReport(currentMonthSessions, previousMonthSessions, currentMonthStats)
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), MonthlyReportData())

    val reflectionPreviews: StateFlow<ReflectionPreviews> = combine(
        weeklyReport,
        monthlyReport,
    ) { weekly, monthly ->
        ReflectionPreviews(
            weeklyMinutes = weekly.currentWeekMinutes,
            weeklySessions = weekly.currentWeekSessions,
            monthlyMinutes = monthly.currentMonthMinutes,
            monthlySessions = monthly.currentMonthSessions,
        )
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), ReflectionPreviews())

    fun setPeriod(period: AnalyticsPeriod) {
        // Free users can only see Week
        // Only users with local premium can access Month/Year analytics
        if (!featureGate.isPro && period != AnalyticsPeriod.Week) {
            return
        }
        _selectedPeriod.value = period
    }

    fun showWeeklyReview() {
        _showWeeklyReview.value = true
    }

    fun dismissWeeklyReview() {
        _showWeeklyReview.value = false
    }

    fun showMonthlyReview() {
        _showMonthlyReview.value = true
    }

    fun dismissMonthlyReview() {
        _showMonthlyReview.value = false
    }

    fun refresh() {
        viewModelScope.launch {
            _isRefreshing.value = true
            // Data is already reactive via Room Flows — brief delay for visual feedback
            kotlinx.coroutines.delay(500)
            _isRefreshing.value = false
        }
    }

    private fun getStatsForPeriod(period: AnalyticsPeriod) = when (period) {
        AnalyticsPeriod.Week -> sessionRepository.getWeekStats()
        AnalyticsPeriod.Month -> sessionRepository.getMonthStats()
        AnalyticsPeriod.Year -> sessionRepository.getYearStats()
    }

    private fun getSessionsForPeriod(period: AnalyticsPeriod): Flow<List<FocusSessionEntity>> = when (period) {
        AnalyticsPeriod.Week -> sessionRepository.getWeekSessions()
        AnalyticsPeriod.Month -> sessionRepository.getMonthSessions()
        AnalyticsPeriod.Year -> sessionRepository.getYearSessions()
    }

    private fun buildStats(
        today: DailyStatsEntity?,
        periodStats: List<DailyStatsEntity>,
        allDays: List<DailyStatsEntity>,
        periodSessions: List<FocusSessionEntity>,
        period: AnalyticsPeriod,
    ): DashboardStats {
        val todayMinutes = today?.totalMinutes ?: 0
        val todaySess = today?.sessionsCompleted ?: 0

        // Filter out break sessions — only count work sessions in stats
        val workSessions = periodSessions.filter { it.phase == null || it.phase == "Work" }

        // Compute totals from RAW sessions for accuracy (avoids DailyStats truncation)
        val periodTotalMillis = workSessions.sumOf { it.durationMillis }
        val periodMinutes = (periodTotalMillis / 60_000).toInt()
        val periodSessionCount = workSessions.size

        val streakResult = StreakProtectionService.computeProtectedStreak(
            history = allDays,
            isPro = featureGate.isPro,
        )
        val streak = streakResult.days
        val bestStreak = sessionRepository.calculateBestStreak(allDays)

        // Chart data (DailyStats is fine for per-day bars — visual approximation)
        val chartData = buildChartData(periodStats, period)

        // Mode breakdown from raw sessions (accurate, breaks excluded)
        val modeBreakdown = buildModeBreakdownFromSessions(workSessions)

        // Productivity patterns from raw sessions (breaks excluded)
        val peakHours = sessionRepository.computePeakHours(workSessions)
        val bestDay = sessionRepository.computeBestDayOfWeek(periodStats)
        val focusScore = computeFocusScore(periodStats)

        // Completion rate from work sessions
        val completedCount = workSessions.count { it.wasCompleted }
        val completionRate = if (periodSessionCount > 0) completedCount.toDouble() / periodSessionCount else 0.0

        // Achievements
        val achievements = computeAchievements(allDays, streak)

        return DashboardStats(
            todayMinutes = todayMinutes,
            todaySessions = todaySess,
            weekMinutes = if (period == AnalyticsPeriod.Week) periodMinutes else 0,
            weekSessions = if (period == AnalyticsPeriod.Week) periodSessionCount else 0,
            currentStreak = streak,
            bestStreak = bestStreak,
            streakProtectionApplied = streakResult.protectionApplied,
            longestSessionMinutes = workSessions.maxOfOrNull { (it.durationMillis / 60_000).toInt() } ?: 0,
            weeklyData = if (period == AnalyticsPeriod.Week) chartData else emptyList(),
            modeBreakdown = modeBreakdown,
            isLoading = false,
            selectedPeriod = period,
            periodMinutes = periodMinutes,
            periodSessions = periodSessionCount,
            chartData = chartData,
            peakHourRange = peakHours,
            bestDayOfWeek = bestDay,
            focusScore = focusScore,
            achievements = achievements,
            completionRate = completionRate,
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

    /** Compute mode breakdown from raw sessions for full precision. */
    private fun buildModeBreakdownFromSessions(sessions: List<FocusSessionEntity>): List<ModeUsage> {
        if (sessions.isEmpty()) return emptyList()
        val byMode = sessions.groupBy { it.mode }
        val totalMillis = sessions.sumOf { it.durationMillis }.coerceAtLeast(1)

        return listOf("Pomodoro", "Flow", "Blocks", "Chrono").mapNotNull { mode ->
            val modeSessions = byMode[mode] ?: return@mapNotNull null
            val modeMillis = modeSessions.sumOf { it.durationMillis }
            if (modeMillis == 0L) return@mapNotNull null
            ModeUsage(
                modeLabel = mode,
                sessions = modeSessions.size,
                totalMinutes = (modeMillis / 60_000).toInt(),
                fraction = modeMillis.toFloat() / totalMillis,
            )
        }
    }

    private fun computeFocusScore(stats: List<DailyStatsEntity>): Int {
        if (stats.isEmpty()) return 0
        val daysWithActivity = stats.count { it.sessionsCompleted > 0 }
        val totalDays = stats.size.coerceAtLeast(1)
        val consistencyRate = daysWithActivity.toFloat() / totalDays
        val avgMinutes = stats.sumOf { it.totalMinutes }.toFloat() / totalDays
        val minuteScore = (avgMinutes / 60f).coerceAtMost(1f)
        return ((consistencyRate * 60 + minuteScore * 40)).toInt().coerceIn(0, 100)
    }

    private fun computeAchievements(
        allDays: List<DailyStatsEntity>,
        currentStreak: Int,
    ): List<Achievement> {
        val totalSessions = allDays.sumOf { it.sessionsCompleted }
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

    /** Weekly report computed from raw sessions for full accuracy. */
    private fun buildWeeklyReport(
        currentWeekSessions: List<FocusSessionEntity>,
        previousWeekSessions: List<FocusSessionEntity>,
        currentWeekStats: List<DailyStatsEntity>,
        allDays: List<DailyStatsEntity>,
    ): WeeklyReportData {
        // Filter out break sessions
        val currentWork = currentWeekSessions.filter { it.phase == null || it.phase == "Work" }
        val previousWork = previousWeekSessions.filter { it.phase == null || it.phase == "Work" }

        // Accurate totals from raw sessions (breaks excluded)
        val currentMinutes = (currentWork.sumOf { it.durationMillis } / 60_000).toInt()
        val currentSessionCount = currentWork.size
        val previousMinutes = (previousWork.sumOf { it.durationMillis } / 60_000).toInt()
        val previousSessionCount = previousWork.size
        val streak = StreakProtectionService.computeProtectedStreak(
            history = allDays,
            isPro = featureGate.isPro,
        ).days

        // Dominant mode from raw sessions (breaks excluded)
        val byMode = currentWork.groupBy { it.mode }
        val modeMillis = byMode.mapValues { (_, sessions) -> sessions.sumOf { it.durationMillis } }
        val dominant = modeMillis.maxByOrNull { it.value }?.takeIf { it.value > 0 }?.key

        // Best day from DailyStats (day-level granularity)
        val dayFormat = SimpleDateFormat("EEEE", Locale.getDefault())
        val cal = Calendar.getInstance()
        val bestDay = currentWeekStats.maxByOrNull { it.totalMinutes }
        val bestDayName = bestDay?.let {
            cal.timeInMillis = it.date
            dayFormat.format(cal.time)
        }

        // Mode distribution from raw sessions (breaks excluded)
        val totalMillis = currentWork.sumOf { it.durationMillis }.coerceAtLeast(1)
        val distribution = listOf("Pomodoro", "Flow", "Blocks", "Chrono").mapNotNull { mode ->
            val modeSessions = byMode[mode] ?: return@mapNotNull null
            val millis = modeSessions.sumOf { it.durationMillis }
            if (millis == 0L) return@mapNotNull null
            ModeUsage(mode, modeSessions.size, (millis / 60_000).toInt(), millis.toFloat() / totalMillis)
        }

        // Weekly chart (DailyStats for per-day bars)
        val chartDayFormat = SimpleDateFormat("EEE", Locale.getDefault())
        val weeklyChart = (6 downTo 0).map { daysAgo ->
            cal.time = Date()
            cal.add(Calendar.DAY_OF_YEAR, -daysAgo)
            cal.set(Calendar.HOUR_OF_DAY, 0); cal.set(Calendar.MINUTE, 0)
            cal.set(Calendar.SECOND, 0); cal.set(Calendar.MILLISECOND, 0)
            val dayStart = cal.timeInMillis
            DailyFocus(chartDayFormat.format(cal.time), currentWeekStats.find { it.date == dayStart }?.totalMinutes ?: 0)
        }

        return WeeklyReportData(
            currentWeekMinutes = currentMinutes,
            currentWeekSessions = currentSessionCount,
            previousWeekMinutes = previousMinutes,
            previousWeekSessions = previousSessionCount,
            dominantMode = dominant,
            bestDayName = bestDayName,
            bestDayMinutes = bestDay?.totalMinutes ?: 0,
            currentStreak = streak,
            modeDistribution = distribution,
            weeklyChartData = weeklyChart,
        )
    }

    /** Monthly report computed from raw sessions for full accuracy. */
    private suspend fun buildMonthlyReport(
        currentMonthSessions: List<FocusSessionEntity>,
        previousMonthSessions: List<FocusSessionEntity>,
        currentMonthStats: List<DailyStatsEntity>,
    ): MonthlyReportData {
        // Filter out break sessions
        val currentWork = currentMonthSessions.filter { it.phase == null || it.phase == "Work" }
        val previousWork = previousMonthSessions.filter { it.phase == null || it.phase == "Work" }

        // Accurate totals from raw sessions
        val currentMinutes = (currentWork.sumOf { it.durationMillis } / 60_000).toInt()
        val currentSessionCount = currentWork.size
        val previousMinutes = (previousWork.sumOf { it.durationMillis } / 60_000).toInt()
        val previousSessionCount = previousWork.size

        // Completion rate
        val completedCount = currentWork.count { it.wasCompleted }
        val completionRate = if (currentSessionCount > 0) completedCount.toDouble() / currentSessionCount else 0.0

        // Dominant mode from raw sessions
        val byMode = currentWork.groupBy { it.mode }
        val modeMillis = byMode.mapValues { (_, sessions) -> sessions.sumOf { it.durationMillis } }
        val dominant = modeMillis.maxByOrNull { it.value }?.takeIf { it.value > 0 }?.key

        // Best week within month
        val cal = Calendar.getInstance()
        val weekTotals = mutableMapOf<Int, Long>()
        for (session in currentWork) {
            cal.timeInMillis = session.startTime
            val weekOfMonth = cal.get(Calendar.WEEK_OF_MONTH)
            weekTotals[weekOfMonth] = (weekTotals[weekOfMonth] ?: 0L) + session.durationMillis
        }
        val bestWeekEntry = weekTotals.maxByOrNull { it.value }
        val bestWeekLabel = bestWeekEntry?.let { "WEEK_LABEL:${it.key}" }
        val bestWeekMinutes = ((bestWeekEntry?.value ?: 0L) / 60_000).toInt()

        // Top 3 tasks by focus time
        val taskMillis = mutableMapOf<String, Long>()
        for (session in currentWork) {
            val taskId = session.linkedTaskId ?: continue
            taskMillis[taskId] = (taskMillis[taskId] ?: 0L) + session.durationMillis
        }
        val topTaskEntries = taskMillis.entries.sortedByDescending { it.value }.take(3)
        val topTasks = topTaskEntries.map { (taskId, millis) ->
            val title = taskRepository.getTaskTitle(taskId)
            TopTaskUsage(
                taskId = taskId,
                taskTitle = title,
                totalMinutes = (millis / 60_000).toInt(),
            )
        }

        // Mode distribution from raw sessions
        val totalMillis = currentWork.sumOf { it.durationMillis }.coerceAtLeast(1)
        val distribution = listOf("Pomodoro", "Flow", "Blocks", "Chrono").mapNotNull { mode ->
            val modeSessions = byMode[mode] ?: return@mapNotNull null
            val millis = modeSessions.sumOf { it.durationMillis }
            if (millis == 0L) return@mapNotNull null
            ModeUsage(mode, modeSessions.size, (millis / 60_000).toInt(), millis.toFloat() / totalMillis)
        }

        // Monthly chart (DailyStats for per-day bars)
        val chartDayFormat = SimpleDateFormat("d", Locale.getDefault())
        val monthlyChart = (29 downTo 0).map { daysAgo ->
            cal.time = Date()
            cal.add(Calendar.DAY_OF_YEAR, -daysAgo)
            cal.set(Calendar.HOUR_OF_DAY, 0); cal.set(Calendar.MINUTE, 0)
            cal.set(Calendar.SECOND, 0); cal.set(Calendar.MILLISECOND, 0)
            val dayStart = cal.timeInMillis
            DailyFocus(chartDayFormat.format(cal.time), currentMonthStats.find { it.date == dayStart }?.totalMinutes ?: 0)
        }

        return MonthlyReportData(
            currentMonthMinutes = currentMinutes,
            currentMonthSessions = currentSessionCount,
            previousMonthMinutes = previousMinutes,
            previousMonthSessions = previousSessionCount,
            dominantMode = dominant,
            bestWeekLabel = bestWeekLabel,
            bestWeekMinutes = bestWeekMinutes,
            completionRate = completionRate,
            topTasks = topTasks,
            modeDistribution = distribution,
            monthlyChartData = monthlyChart,
        )
    }
}
