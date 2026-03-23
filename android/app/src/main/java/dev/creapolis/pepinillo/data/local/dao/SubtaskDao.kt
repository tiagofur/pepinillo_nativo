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

    @Query("SELECT * FROM subtasks WHERE task_id = :taskId ORDER BY sort_order ASC")
    fun getSubtasksForTask(taskId: String): Flow<List<SubtaskEntity>>

    @Query("SELECT COUNT(*) FROM subtasks WHERE task_id = :taskId")
    fun getSubtaskCount(taskId: String): Flow<Int>

    @Query("SELECT COUNT(*) FROM subtasks WHERE task_id = :taskId AND is_completed = 1")
    fun getCompletedSubtaskCount(taskId: String): Flow<Int>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertSubtask(subtask: SubtaskEntity)

    @Update
    suspend fun updateSubtask(subtask: SubtaskEntity)

    @Query("DELETE FROM subtasks WHERE id = :subtaskId")
    suspend fun deleteSubtaskById(subtaskId: String)

    @Query("UPDATE subtasks SET is_completed = NOT is_completed WHERE id = :subtaskId")
    suspend fun toggleCompletion(subtaskId: String)

    // Sync queries
    @Query("SELECT * FROM subtasks WHERE task_id = :taskId ORDER BY sort_order ASC")
    suspend fun getSubtasksForTaskSync(taskId: String): List<SubtaskEntity>

    @Query("SELECT * FROM subtasks WHERE is_dirty = 1")
    suspend fun getDirtySubtasks(): List<SubtaskEntity>

    @Query("UPDATE subtasks SET is_dirty = 0 WHERE task_id = :taskId")
    suspend fun markSubtasksSynced(taskId: String)
}
