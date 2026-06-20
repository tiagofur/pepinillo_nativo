package dev.creapolis.pepinillo.feature.dashboard.model

enum class AnalyticsPeriod(val label: String) {
    Week("7D"),
    Month("30D"),
    Year("Year"),
}

enum class Trend {
    Up, Down, Neutral
}

data class DailyFocus(
    val dayLabel: String,
    val minutes: Int,
)

data class ModeUsage(
    val modeLabel: String,
    val sessions: Int,
    val totalMinutes: Int,
    val fraction: Float,
)

data class WeeklyReportData(
    val currentWeekMinutes: Int = 0,
    val currentWeekSessions: Int = 0,
    val previousWeekMinutes: Int = 0,
    val previousWeekSessions: Int = 0,
    val dominantMode: String? = null,
    val bestDayName: String? = null,
    val bestDayMinutes: Int = 0,
    val currentStreak: Int = 0,
    val modeDistribution: List<ModeUsage> = emptyList(),
    val weeklyChartData: List<DailyFocus> = emptyList(),
) {
    val minutesDelta: Int get() = currentWeekMinutes - previousWeekMinutes
    val sessionsDelta: Int get() = currentWeekSessions - previousWeekSessions
    val minutesTrend: Trend get() = when {
        minutesDelta > 0 -> Trend.Up
        minutesDelta < 0 -> Trend.Down
        else -> Trend.Neutral
    }
    val sessionsTrend: Trend get() = when {
        sessionsDelta > 0 -> Trend.Up
        sessionsDelta < 0 -> Trend.Down
        else -> Trend.Neutral
    }
}

data class TopTaskUsage(
    val taskId: String,
    val taskTitle: String,
    val totalMinutes: Int,
)

data class MonthlyReportData(
    val currentMonthMinutes: Int = 0,
    val currentMonthSessions: Int = 0,
    val previousMonthMinutes: Int = 0,
    val previousMonthSessions: Int = 0,
    val dominantMode: String? = null,
    val bestWeekLabel: String? = null,
    val bestWeekMinutes: Int = 0,
    val completionRate: Double = 0.0,
    val topTasks: List<TopTaskUsage> = emptyList(),
    val modeDistribution: List<ModeUsage> = emptyList(),
    val monthlyChartData: List<DailyFocus> = emptyList(),
) {
    val minutesDelta: Int get() = currentMonthMinutes - previousMonthMinutes
    val sessionsDelta: Int get() = currentMonthSessions - previousMonthSessions
    val minutesTrend: Trend get() = when {
        minutesDelta > 0 -> Trend.Up
        minutesDelta < 0 -> Trend.Down
        else -> Trend.Neutral
    }
    val sessionsTrend: Trend get() = when {
        sessionsDelta > 0 -> Trend.Up
        sessionsDelta < 0 -> Trend.Down
        else -> Trend.Neutral
    }
}

data class Achievement(
    val id: String,
    val title: String,
    val icon: String,
    val isUnlocked: Boolean,
    val progress: Float, // 0.0-1.0
    val progressText: String, // e.g. "3/10"
)

data class DashboardStats(
    val todayMinutes: Int = 0,
    val todaySessions: Int = 0,
    val weekMinutes: Int = 0,
    val weekSessions: Int = 0,
    val currentStreak: Int = 0,
    val bestStreak: Int = 0,
    val streakProtectionApplied: Boolean = false,
    val longestSessionMinutes: Int = 0,
    val weeklyData: List<DailyFocus> = emptyList(),
    val modeBreakdown: List<ModeUsage> = emptyList(),
    val isLoading: Boolean = true,
    val selectedPeriod: AnalyticsPeriod = AnalyticsPeriod.Week,
    val periodMinutes: Int = 0,
    val periodSessions: Int = 0,
    val chartData: List<DailyFocus> = emptyList(),
    val peakHourRange: String = "",
    val bestDayOfWeek: String = "",
    val focusScore: Int = 0,
    val achievements: List<Achievement> = emptyList(),
    val completionRate: Double = 0.0,
)

data class ReflectionPreviews(
    val weeklyMinutes: Int = 0,
    val weeklySessions: Int = 0,
    val monthlyMinutes: Int = 0,
    val monthlySessions: Int = 0,
)

val DashboardStats.isEmpty: Boolean
    get() = todayMinutes == 0 && weekMinutes == 0 && currentStreak == 0 && bestStreak == 0
