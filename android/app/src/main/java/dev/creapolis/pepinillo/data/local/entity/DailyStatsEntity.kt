package dev.creapolis.pepinillo.data.local.entity

import androidx.room.ColumnInfo
import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "daily_stats")
data class DailyStatsEntity(
    @PrimaryKey
    val date: Long, // epoch millis for start of day
    @ColumnInfo(name = "total_minutes")
    val totalMinutes: Int = 0,
    @ColumnInfo(name = "sessions_completed")
    val sessionsCompleted: Int = 0,
    @ColumnInfo(name = "tasks_completed")
    val tasksCompleted: Int = 0,
    @ColumnInfo(name = "longest_session_minutes")
    val longestSessionMinutes: Int = 0,
    @ColumnInfo(name = "pomodoro_minutes")
    val pomodoroMinutes: Int = 0,
    @ColumnInfo(name = "flow_minutes")
    val flowMinutes: Int = 0,
    @ColumnInfo(name = "blocks_minutes")
    val blocksMinutes: Int = 0,
    @ColumnInfo(name = "stopwatch_minutes")
    val stopwatchMinutes: Int = 0,
)
