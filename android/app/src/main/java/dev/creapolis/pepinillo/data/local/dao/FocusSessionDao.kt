package dev.creapolis.pepinillo.data.local.dao

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.Query
import dev.creapolis.pepinillo.data.local.entity.FocusSessionEntity
import kotlinx.coroutines.flow.Flow

@Dao
interface FocusSessionDao {

    @Insert
    suspend fun insertSession(session: FocusSessionEntity)

    @Query("SELECT * FROM focus_sessions WHERE created_at >= :startOfDay ORDER BY created_at DESC")
    fun getSessionsForDay(startOfDay: Long): Flow<List<FocusSessionEntity>>

    @Query("SELECT COUNT(*) FROM focus_sessions WHERE created_at >= :startOfDay")
    fun getSessionCountForDay(startOfDay: Long): Flow<Int>

    @Query("SELECT * FROM focus_sessions WHERE created_at >= :startTime AND created_at < :endTime ORDER BY created_at DESC")
    fun getSessionsInRange(startTime: Long, endTime: Long): Flow<List<FocusSessionEntity>>
}
