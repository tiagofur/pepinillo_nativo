package dev.creapolis.pepinillo.widget

import android.content.Context
import androidx.glance.appwidget.updateAll

object WidgetStateManager {

    suspend fun updateDailyStats(
        context: Context,
        totalMinutes: Int,
        sessions: Int,
        streak: Int,
        completedTasksToday: Int = 0,
    ) {
        updateStatsWidgetState(
            context = context,
            totalMinutes = totalMinutes,
            sessions = sessions,
            streak = streak,
            completedTasksToday = completedTasksToday,
        )
        DailyStatsWidget().updateAll(context)
    }
}
