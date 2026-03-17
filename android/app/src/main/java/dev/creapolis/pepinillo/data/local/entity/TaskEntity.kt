package dev.creapolis.pepinillo.data.local.entity

import androidx.room.ColumnInfo
import androidx.room.Entity
import androidx.room.PrimaryKey
import java.util.UUID

@Entity(tableName = "tasks")
data class TaskEntity(
    @PrimaryKey
    val id: String = UUID.randomUUID().toString(),
    val title: String,
    val notes: String? = null,
    @ColumnInfo(name = "is_completed")
    val isCompleted: Boolean = false,
    @ColumnInfo(name = "completed_at")
    val completedAt: Long? = null,
    val priority: String = "None",
    @ColumnInfo(name = "energy_level")
    val energyLevel: String = "Regular",
    @ColumnInfo(name = "estimated_pomodoros")
    val estimatedPomodoros: Int = 1,
    @ColumnInfo(name = "completed_pomodoros")
    val completedPomodoros: Int = 0,
    @ColumnInfo(name = "sort_order")
    val sortOrder: Int = 0,
    @ColumnInfo(name = "created_at")
    val createdAt: Long = System.currentTimeMillis(),
    @ColumnInfo(name = "updated_at")
    val updatedAt: Long = System.currentTimeMillis(),
)
