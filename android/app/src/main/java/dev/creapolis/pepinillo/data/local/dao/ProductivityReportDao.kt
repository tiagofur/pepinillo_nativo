package dev.creapolis.pepinillo.data.local.dao

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import dev.creapolis.pepinillo.data.local.entity.ProductivityReportEntity

@Dao
interface ProductivityReportDao {

    @Query("SELECT * FROM productivity_reports WHERE period = :period AND period_start = :periodStart LIMIT 1")
    suspend fun getReport(period: String, periodStart: Long): ProductivityReportEntity?

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertReport(report: ProductivityReportEntity)

    @Query("DELETE FROM productivity_reports WHERE generated_at < :before")
    suspend fun deleteOldReports(before: Long)

    @Query("DELETE FROM productivity_reports")
    suspend fun deleteAll()
}
