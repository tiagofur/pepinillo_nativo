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
    // Last completion instant for recurring occurrences. advanceRecurringTask stamps
    // this while keeping isCompleted=false (the series stays active), so daily
    // "tasks completed" counts occurrences instead of missing them (C2).
    @ColumnInfo(name = "last_completed_at")
    val lastCompletedAt: Long? = null,
    val priority: String = "None",
    @ColumnInfo(name = "energy_level")
    val energyLevel: String = "Regular",
    @ColumnInfo(name = "estimated_pomodoros")
    val estimatedPomodoros: Int = 1,
    @ColumnInfo(name = "completed_pomodoros")
    val completedPomodoros: Int = 0,
    @ColumnInfo(name = "sort_order")
    val sortOrder: Int = 0,
    @ColumnInfo(name = "due_date")
    val dueDate: Long? = null,
    @ColumnInfo(name = "scheduled_for_today", defaultValue = "0")
    val scheduledForToday: Boolean = false,
    @ColumnInfo(name = "recurrence_rule")
    val recurrenceRule: String? = null,
    @ColumnInfo(name = "next_occurrence")
    val nextOccurrence: Long? = null,
    @ColumnInfo(name = "is_recurring_template", defaultValue = "0")
    val isRecurringTemplate: Boolean = false,
    @ColumnInfo(name = "recurring_template_id")
    val recurringTemplateID: String? = null,
    @ColumnInfo(name = "created_at")
    val createdAt: Long = System.currentTimeMillis(),
    @ColumnInfo(name = "updated_at")
    val updatedAt: Long = System.currentTimeMillis(),
    // Sync fields
    @ColumnInfo(name = "server_id")
    val serverId: Int? = null,
    @ColumnInfo(name = "is_dirty", defaultValue = "1")
    val isDirty: Boolean = true,
    @ColumnInfo(name = "is_deleted", defaultValue = "0")
    val isDeleted: Boolean = false,
    @ColumnInfo(name = "synced_at")
    val syncedAt: Long? = null,
)
