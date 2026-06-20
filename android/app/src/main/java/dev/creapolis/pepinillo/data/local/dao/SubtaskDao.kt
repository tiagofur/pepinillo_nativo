package dev.creapolis.pepinillo.data.local.dao

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import androidx.room.Update
import dev.creapolis.pepinillo.data.local.entity.SubtaskEntity
import kotlinx.coroutines.flow.Flow

@Dao
interface SubtaskDao {

    @Query("SELECT * FROM subtasks WHERE task_id = :taskId AND is_deleted = 0 ORDER BY sort_order ASC")
    fun getSubtasksForTask(taskId: String): Flow<List<SubtaskEntity>>

    @Query("SELECT COUNT(*) FROM subtasks WHERE task_id = :taskId AND is_deleted = 0")
    fun getSubtaskCount(taskId: String): Flow<Int>

    @Query("SELECT COUNT(*) FROM subtasks WHERE task_id = :taskId AND is_completed = 1 AND is_deleted = 0")
    fun getCompletedSubtaskCount(taskId: String): Flow<Int>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertSubtask(subtask: SubtaskEntity)

    @Update
    suspend fun updateSubtask(subtask: SubtaskEntity)

    /** Returns the parent task id for a subtask (independent of its soft-delete state). */
    @Query("SELECT task_id FROM subtasks WHERE id = :subtaskId")
    suspend fun getTaskIdForSubtask(subtaskId: String): String?

    /**
     * Soft-delete: marks the subtask as deleted and dirty so the next sync push
     * propagates the deletion to the server. Hard-deletes would be silently lost
     * because [dev.creapolis.pepinillo.data.sync.SyncEngine] only sees subtasks via
     * their parent task and drops non-dirty rows on merge.
     */
    @Query("UPDATE subtasks SET is_deleted = 1, is_dirty = 1, updated_at = :now WHERE id = :subtaskId")
    suspend fun deleteSubtaskById(subtaskId: String, now: Long = System.currentTimeMillis())

    /** Escape hatch: physical row removal. Reserved for sync merge/purge paths. */
    @Query("DELETE FROM subtasks WHERE id = :subtaskId")
    suspend fun hardDeleteById(subtaskId: String)

    /**
     * Toggle completion atomically and mark the row dirty + bumped, so the change
     * survives the next sync instead of being overwritten by the server snapshot.
     */
    @Query(
        "UPDATE subtasks SET is_completed = NOT is_completed, is_dirty = 1, updated_at = :now WHERE id = :subtaskId",
    )
    suspend fun toggleCompletion(subtaskId: String, now: Long = System.currentTimeMillis())

    // Sync queries
    // NOTE: the snapshot excludes soft-deleted rows so the server reconciles them away
    // via the full-replacement task-sync model (parent task is marked dirty on subtask
    // mutations, so the next push carries the up-to-date non-deleted subtask list).
    @Query("SELECT * FROM subtasks WHERE task_id = :taskId AND is_deleted = 0 ORDER BY sort_order ASC")
    suspend fun getSubtasksForTaskSync(taskId: String): List<SubtaskEntity>

    @Query("SELECT * FROM subtasks WHERE is_dirty = 1")
    suspend fun getDirtySubtasks(): List<SubtaskEntity>

    @Query("UPDATE subtasks SET is_dirty = 0 WHERE task_id = :taskId")
    suspend fun markSubtasksSynced(taskId: String)

    @Query("DELETE FROM subtasks WHERE task_id = :taskId")
    suspend fun deleteSubtasksForTask(taskId: String)

    @Query("DELETE FROM subtasks WHERE task_id = :taskId AND is_dirty = 0")
    suspend fun deleteNonDirtySubtasksForTask(taskId: String)

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertAll(subtasks: List<SubtaskEntity>)

    @Query("SELECT * FROM subtasks WHERE task_id = :taskId AND is_dirty = 1 ORDER BY sort_order ASC")
    suspend fun getDirtySubtasksForTask(taskId: String): List<SubtaskEntity>

    @Query("DELETE FROM subtasks")
    suspend fun deleteAll()
}
