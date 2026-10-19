package dev.creapolis.pepinillo.data.local.dao

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import androidx.room.Transaction
import androidx.room.Upsert
import dev.creapolis.pepinillo.data.local.entity.FocusSessionEntity
import kotlinx.coroutines.flow.Flow

@Dao
interface FocusSessionDao {

    @Insert
    suspend fun insertSession(session: FocusSessionEntity)

    @Query("SELECT * FROM focus_sessions WHERE start_time >= :startOfDay AND start_time < :endOfDay ORDER BY start_time DESC")
    fun getSessionsForDay(startOfDay: Long, endOfDay: Long): Flow<List<FocusSessionEntity>>

    @Query("SELECT COUNT(*) FROM focus_sessions WHERE start_time >= :startOfDay AND start_time < :endOfDay AND (phase IS NULL OR phase = 'Work')")
    fun getSessionCountForDay(startOfDay: Long, endOfDay: Long): Flow<Int>

    @Query("SELECT * FROM focus_sessions WHERE start_time >= :startTime AND start_time < :endTime ORDER BY start_time DESC")
    fun getSessionsInRange(startTime: Long, endTime: Long): Flow<List<FocusSessionEntity>>

    @Query("SELECT * FROM focus_sessions WHERE linked_task_id = :taskId ORDER BY start_time DESC")
    fun getSessionsForTask(taskId: String): Flow<List<FocusSessionEntity>>

    @Query("SELECT COUNT(*) FROM focus_sessions WHERE start_time >= :startOfDay AND start_time < :endOfDay AND mode = 'Pomodoro' AND phase = 'Work'")
    suspend fun getTodayPomodoroWorkCount(startOfDay: Long, endOfDay: Long): Int

    @Query("UPDATE focus_sessions SET journal_note = :journalNote, satisfaction_rating = :satisfactionRating, is_dirty = 1, updated_at = :now WHERE id = :sessionId")
    suspend fun updateJournalEntry(sessionId: String, journalNote: String?, satisfactionRating: Int?, now: Long)

    // Sync queries
    @Query("SELECT * FROM focus_sessions WHERE is_dirty = 1")
    suspend fun getDirtySessions(): List<FocusSessionEntity>

    @Query("UPDATE focus_sessions SET is_dirty = 0, synced_at = :syncedAt WHERE id = :sessionId")
    suspend fun markSynced(sessionId: String, syncedAt: Long)

    /**
     * Marks many sessions as synced in a single transaction. All sessions share the same syncedAt,
     * so this collapses N separate UPDATEs into one committed transaction.
     */
    @Transaction
    suspend fun markSyncedBatch(sessionIds: List<String>, syncedAt: Long) {
        for (id in sessionIds) {
            markSynced(id, syncedAt)
        }
    }

    @Query("SELECT * FROM focus_sessions WHERE start_time >= :startTime AND start_time < :endTime ORDER BY start_time DESC")
    suspend fun getSessionsInRangeSync(startTime: Long, endTime: Long): List<FocusSessionEntity>

    @Query("SELECT * FROM focus_sessions WHERE id = :sessionId")
    suspend fun getSessionById(sessionId: String): FocusSessionEntity?

    @Insert(onConflict = OnConflictStrategy.IGNORE)
    suspend fun insertIfNotExists(session: FocusSessionEntity)

    @Upsert
    suspend fun upsertSession(session: FocusSessionEntity)

    @Upsert
    suspend fun upsertSessions(sessions: List<FocusSessionEntity>)

    @Query("SELECT * FROM focus_sessions ORDER BY created_at DESC")
    suspend fun getAllSessionsSync(): List<FocusSessionEntity>

    @Query("SELECT COUNT(*) FROM focus_sessions")
    suspend fun getSessionCount(): Int

    @Query("UPDATE focus_sessions SET linked_task_id = :taskId WHERE id = :sessionId")
    suspend fun updateLinkedTaskId(sessionId: String, taskId: String)

    @Query("DELETE FROM focus_sessions")
    suspend fun deleteAll()

    @Query("SELECT COUNT(*) FROM focus_sessions WHERE is_dirty = 1")
    fun getDirtySessionCount(): Flow<Int>
}
