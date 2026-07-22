package dev.creapolis.pepinillo.data.local.dao

import androidx.room.Dao
import androidx.room.Query
import androidx.room.Upsert
import dev.creapolis.pepinillo.data.local.entity.DailyStatsEntity
import kotlinx.coroutines.flow.Flow

@Dao
interface DailyStatsDao {

    @Upsert
    suspend fun upsert(stats: DailyStatsEntity)

    @Query("SELECT * FROM daily_stats WHERE date = :date")
    suspend fun getStatsForDate(date: Long): DailyStatsEntity?

    @Query("SELECT * FROM daily_stats WHERE date = :date")
    fun observeStatsForDate(date: Long): Flow<DailyStatsEntity?>

    @Query("SELECT * FROM daily_stats WHERE date >= :startDate AND date <= :endDate ORDER BY date ASC")
    fun getStatsInRange(startDate: Long, endDate: Long): Flow<List<DailyStatsEntity>>

    @Query("SELECT * FROM daily_stats WHERE sessions_completed > 0 ORDER BY date DESC")
    fun getAllDaysWithSessions(): Flow<List<DailyStatsEntity>>

    @Query("DELETE FROM daily_stats")
    suspend fun deleteAll()

    @Query("SELECT * FROM daily_stats WHERE is_dirty = 1")
    suspend fun getDirtyStats(): List<DailyStatsEntity>

    @Query("UPDATE daily_stats SET is_dirty = 0, synced_at = :syncedAt WHERE date = :date")
    suspend fun markSynced(date: Long, syncedAt: Long)
}
