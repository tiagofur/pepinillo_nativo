package dev.creapolis.pepinillo.data.local.entity

import androidx.room.ColumnInfo
import androidx.room.Entity
import androidx.room.PrimaryKey
import java.util.UUID

@Entity(tableName = "focus_sessions")
data class FocusSessionEntity(
    @PrimaryKey
    val id: String = UUID.randomUUID().toString(),
    val mode: String,
    @ColumnInfo(name = "start_time")
    val startTime: Long,
    @ColumnInfo(name = "end_time")
    val endTime: Long,
    @ColumnInfo(name = "duration_millis")
    val durationMillis: Long,
    @ColumnInfo(name = "linked_task_id")
    val linkedTaskId: String? = null,
    val phase: String? = null,
    @ColumnInfo(name = "created_at")
    val createdAt: Long = System.currentTimeMillis(),
    @ColumnInfo(name = "updated_at")
    val updatedAt: Long = System.currentTimeMillis(),
    // Productivity data fields
    @ColumnInfo(name = "was_completed", defaultValue = "1")
    val wasCompleted: Boolean = true,
    @ColumnInfo(name = "interruptions", defaultValue = "0")
    val interruptions: Int = 0,
    @ColumnInfo(name = "pause_count", defaultValue = "0")
    val pauseCount: Int = 0,
    @ColumnInfo(name = "total_pause_millis", defaultValue = "0")
    val totalPauseMillis: Long = 0,
    @ColumnInfo(name = "pomodoro_number")
    val pomodoroNumber: Int? = null,
    @ColumnInfo(name = "journal_note")
    val journalNote: String? = null,
    @ColumnInfo(name = "satisfaction_rating")
    val satisfactionRating: Int? = null,
    @ColumnInfo(name = "target_duration_millis")
    val targetDurationMillis: Long? = null,
    // Sync fields
    @ColumnInfo(name = "is_dirty", defaultValue = "1")
    val isDirty: Boolean = true,
    @ColumnInfo(name = "synced_at")
    val syncedAt: Long? = null,
)
