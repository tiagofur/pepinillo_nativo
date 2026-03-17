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
)
