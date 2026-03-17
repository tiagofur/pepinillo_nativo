package dev.creapolis.pepinillo.feature.dashboard.model

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

data class DashboardStats(
    val todayMinutes: Int = 0,
    val todaySessions: Int = 0,
    val weekMinutes: Int = 0,
    val weekSessions: Int = 0,
    val currentStreak: Int = 0,
    val bestStreak: Int = 0,
    val longestSessionMinutes: Int = 0,
    val weeklyData: List<DailyFocus> = emptyList(),
    val modeBreakdown: List<ModeUsage> = emptyList(),
    val isLoading: Boolean = true,
)

val DashboardStats.isEmpty: Boolean
    get() = todayMinutes == 0 && weekMinutes == 0 && currentStreak == 0 && bestStreak == 0
