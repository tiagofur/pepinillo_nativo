package dev.creapolis.pepinillo.data.local.entity

import androidx.room.ColumnInfo
import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "preference_sync_metadata")
data class PreferenceSyncEntity(
    @PrimaryKey
    val key: String,
    @ColumnInfo(name = "updated_at")
    val updatedAt: Long, // epoch millis
    @ColumnInfo(name = "is_dirty", defaultValue = "1")
    val isDirty: Boolean = true,
)
