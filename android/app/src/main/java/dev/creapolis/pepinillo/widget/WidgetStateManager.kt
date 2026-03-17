package dev.creapolis.pepinillo.widget

import android.content.Context
import android.content.SharedPreferences
import androidx.glance.appwidget.updateAll
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

object WidgetStateManager {

    private const val PREFS = "pepinillo_widget"

    const val KEY_MINUTES = "minutes"
    const val KEY_SESSIONS = "sessions"
    const val KEY_STREAK = "streak"

    private fun prefs(ctx: Context): SharedPreferences =
        ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    suspend fun updateDailyStats(context: Context, totalMinutes: Int, sessions: Int, streak: Int) {
        prefs(context).edit()
            .putInt(KEY_MINUTES, totalMinutes)
            .putInt(KEY_SESSIONS, sessions)
            .putInt(KEY_STREAK, streak)
            .apply()

        withContext(Dispatchers.IO) { DailyStatsWidget().updateAll(context) }
    }

    fun readMinutes(ctx: Context): Int = prefs(ctx).getInt(KEY_MINUTES, 0)
    fun readSessions(ctx: Context): Int = prefs(ctx).getInt(KEY_SESSIONS, 0)
    fun readStreak(ctx: Context): Int = prefs(ctx).getInt(KEY_STREAK, 0)
}
