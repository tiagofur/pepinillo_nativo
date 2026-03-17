package dev.creapolis.pepinillo.data.local.dao

import androidx.room.Dao
import androidx.room.Delete
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import androidx.room.Update
import dev.creapolis.pepinillo.data.local.entity.TaskEntity
import kotlinx.coroutines.flow.Flow

@Dao
interface TaskDao {

    @Query("SELECT * FROM tasks WHERE is_deleted = 0 ORDER BY is_completed ASC, sort_order ASC, created_at DESC")
    fun getAllTasks(): Flow<List<TaskEntity>>

    @Query("SELECT * FROM tasks WHERE is_completed = 0 AND is_deleted = 0 ORDER BY sort_order ASC, created_at DESC")
    fun getActiveTasks(): Flow<List<TaskEntity>>

    @Query("SELECT * FROM tasks WHERE is_completed = 1 AND is_deleted = 0 ORDER BY completed_at DESC")
    fun getCompletedTasks(): Flow<List<TaskEntity>>

    @Query("SELECT * FROM tasks WHERE id = :taskId")
    suspend fun getTaskById(taskId: String): TaskEntity?

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertTask(task: TaskEntity)

    @Update
    suspend fun updateTask(task: TaskEntity)

    @Delete
    suspend fun deleteTask(task: TaskEntity)

    @Query("DELETE FROM tasks WHERE id = :taskId")
    suspend fun deleteTaskById(taskId: String)

    @Query("UPDATE tasks SET completed_pomodoros = completed_pomodoros + 1, updated_at = :now WHERE id = :taskId")
    suspend fun incrementPomodoros(taskId: String, now: Long = System.currentTimeMillis())

    @Query("SELECT COUNT(*) FROM tasks WHERE is_completed = 0 AND is_deleted = 0")
    fun getActiveCount(): Flow<Int>

    // Sync queries
    @Query("SELECT * FROM tasks WHERE is_dirty = 1")
    suspend fun getDirtyTasks(): List<TaskEntity>

    @Query("UPDATE tasks SET is_dirty = 0, synced_at = :syncedAt, server_id = :serverId WHERE id = :taskId")
    suspend fun markSynced(taskId: String, syncedAt: Long, serverId: Int)

    @Query("UPDATE tasks SET is_deleted = 1, is_dirty = 1, updated_at = :now WHERE id = :taskId")
    suspend fun softDelete(taskId: String, now: Long = System.currentTimeMillis())

    @Query("DELETE FROM tasks WHERE is_deleted = 1 AND is_dirty = 0")
    suspend fun purgeDeletedSynced()

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsertAll(tasks: List<TaskEntity>)
}
