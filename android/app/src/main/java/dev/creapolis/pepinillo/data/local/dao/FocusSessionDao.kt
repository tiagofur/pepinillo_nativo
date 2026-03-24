package dev.creapolis.pepinillo.data.local.dao

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import dev.creapolis.pepinillo.data.local.entity.FocusSessionEntity
import kotlinx.coroutines.flow.Flow

@Dao
interface FocusSessionDao {

    @Insert
    suspend fun insertSession(session: FocusSessionEntity)

    @Query("SELECT * FROM focus_sessions WHERE created_at >= :startOfDay ORDER BY created_at DESC")
    fun getSessionsForDay(startOfDay: Long): Flow<List<FocusSessionEntity>>

    @Query("SELECT COUNT(*) FROM focus_sessions WHERE created_at >= :startOfDay AND (phase IS NULL OR phase = 'Work')")
    fun getSessionCountForDay(startOfDay: Long): Flow<Int>

    @Query("SELECT * FROM focus_sessions WHERE created_at >= :startTime AND created_at < :endTime ORDER BY created_at DESC")
    fun getSessionsInRange(startTime: Long, endTime: Long): Flow<List<FocusSessionEntity>>

    @Query("SELECT * FROM focus_sessions WHERE linked_task_id = :taskId ORDER BY created_at DESC")
    fun getSessionsForTask(taskId: String): Flow<List<FocusSessionEntity>>

    @Query("SELECT COUNT(*) FROM focus_sessions WHERE created_at >= :startOfDay AND mode = 'Pomodoro' AND phase = 'Work'")
    suspend fun getTodayPomodoroWorkCount(startOfDay: Long): Int

    @Query("UPDATE focus_sessions SET journal_note = :journalNote, satisfaction_rating = :satisfactionRating, is_dirty = 1 WHERE id = :sessionId")
    suspend fun updateJournalEntry(sessionId: String, journalNote: String?, satisfactionRating: Int?)

    // Sync queries
    @Query("SELECT * FROM focus_sessions WHERE is_dirty = 1")
    suspend fun getDirtySessions(): List<FocusSessionEntity>

    @Query("UPDATE focus_sessions SET is_dirty = 0, synced_at = :syncedAt WHERE id = :sessionId")
    suspend fun markSynced(sessionId: String, syncedAt: Long)

    @Query("SELECT * FROM focus_sessions WHERE created_at >= :startTime AND created_at < :endTime ORDER BY created_at DESC")
    suspend fun getSessionsInRangeSync(startTime: Long, endTime: Long): List<FocusSessionEntity>

    @Query("SELECT * FROM focus_sessions WHERE id = :sessionId")
    suspend fun getSessionById(sessionId: String): FocusSessionEntity?

    @Insert(onConflict = OnConflictStrategy.IGNORE)
    suspend fun insertIfNotExists(session: FocusSessionEntity)
}
