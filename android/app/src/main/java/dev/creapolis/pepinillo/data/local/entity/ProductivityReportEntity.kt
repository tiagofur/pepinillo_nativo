package dev.creapolis.pepinillo.data.local.entity

import androidx.room.ColumnInfo
import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "productivity_reports")
data class ProductivityReportEntity(
    @PrimaryKey val id: String,
    val period: String,
    @ColumnInfo(name = "period_start") val periodStart: Long,
    @ColumnInfo(name = "period_end") val periodEnd: Long,
    @ColumnInfo(name = "generated_at") val generatedAt: Long,
    val title: String,
    val highlights: String,
    val insights: String,
    val recommendations: String,
    @ColumnInfo(name = "raw_payload") val rawPayload: String,
)
