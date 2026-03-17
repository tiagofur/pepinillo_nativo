package dev.creapolis.pepinillo.feature.dashboard

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import dagger.hilt.android.lifecycle.HiltViewModel
import dev.creapolis.pepinillo.data.local.entity.DailyStatsEntity
import dev.creapolis.pepinillo.data.repository.SessionRepository
import dev.creapolis.pepinillo.feature.dashboard.model.DailyFocus
import dev.creapolis.pepinillo.feature.dashboard.model.DashboardStats
import dev.creapolis.pepinillo.feature.dashboard.model.ModeUsage
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.stateIn
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale
import javax.inject.Inject

@HiltViewModel
class DashboardViewModel @Inject constructor(
    private val sessionRepository: SessionRepository,
) : ViewModel() {

    val stats: StateFlow<DashboardStats> = combine(
        sessionRepository.getTodayStats(),
        sessionRepository.getWeekStats(),
        sessionRepository.getAllDaysWithSessions(),
    ) { todayStats, weekStats, allDays ->
        buildStats(todayStats, weekStats, allDays)
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), DashboardStats())

    private fun buildStats(
        today: DailyStatsEntity?,
        weekStats: List<DailyStatsEntity>,
        allDays: List<DailyStatsEntity>,
    ): DashboardStats {
        val todayMinutes = today?.totalMinutes ?: 0
        val todaySessions = today?.sessionsCompleted ?: 0
        val weekMinutes = weekStats.sumOf { it.totalMinutes }
        val weekSessions = weekStats.sumOf { it.sessionsCompleted }
        val longestSession = (weekStats + listOfNotNull(today)).maxOfOrNull { it.longestSessionMinutes } ?: 0

        // Build weekly chart data (last 7 days)
        val dayFormat = SimpleDateFormat("EEE", Locale.getDefault())
        val cal = Calendar.getInstance()
        val weeklyData = (6 downTo 0).map { daysAgo ->
            cal.time = Date()
            cal.add(Calendar.DAY_OF_YEAR, -daysAgo)
            cal.set(Calendar.HOUR_OF_DAY, 0)
            cal.set(Calendar.MINUTE, 0)
            cal.set(Calendar.SECOND, 0)
            cal.set(Calendar.MILLISECOND, 0)
            val dayStart = cal.timeInMillis
            val dayLabel = dayFormat.format(cal.time)
            val dayStats = weekStats.find { it.date == dayStart }
            DailyFocus(dayLabel, dayStats?.totalMinutes ?: 0)
        }

        // Mode breakdown from week stats
        val totalModeMinutes = weekStats.sumOf {
            it.pomodoroMinutes + it.flowMinutes + it.blocksMinutes + it.stopwatchMinutes
        }.coerceAtLeast(1)
        val pomodoroMin = weekStats.sumOf { it.pomodoroMinutes }
        val flowMin = weekStats.sumOf { it.flowMinutes }
        val blocksMin = weekStats.sumOf { it.blocksMinutes }
        val stopwatchMin = weekStats.sumOf { it.stopwatchMinutes }

        val modeBreakdown = listOf(
            ModeUsage("Pomodoro", 0, pomodoroMin, pomodoroMin.toFloat() / totalModeMinutes),
            ModeUsage("Flow", 0, flowMin, flowMin.toFloat() / totalModeMinutes),
            ModeUsage("Blocks", 0, blocksMin, blocksMin.toFloat() / totalModeMinutes),
            ModeUsage("Chrono", 0, stopwatchMin, stopwatchMin.toFloat() / totalModeMinutes),
        ).filter { it.totalMinutes > 0 }

        // Calculate streak
        val streak = sessionRepository.calculateCurrentStreak(allDays)
        val bestStreak = sessionRepository.calculateBestStreak(allDays)

        return DashboardStats(
            todayMinutes = todayMinutes,
            todaySessions = todaySessions,
            weekMinutes = weekMinutes,
            weekSessions = weekSessions,
            currentStreak = streak,
            bestStreak = bestStreak,
            longestSessionMinutes = longestSession,
            weeklyData = weeklyData,
            modeBreakdown = modeBreakdown,
            isLoading = false,
        )
    }

}
