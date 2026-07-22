package dev.creapolis.pepinillo.data.local.dao

import androidx.room.Dao
import androidx.room.Delete
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import androidx.room.Transaction
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

    @Query("SELECT * FROM tasks WHERE scheduled_for_today = 1 AND is_completed = 0 AND is_deleted = 0 ORDER BY sort_order ASC, created_at DESC")
    fun getTasksScheduledForToday(): Flow<List<TaskEntity>>

    @Query("SELECT * FROM tasks WHERE id = :taskId")
    suspend fun getTaskById(taskId: String): TaskEntity?

    /** Batch lookup by sync ids — returns a Map for O(1) membership in sync loops. */
    @Query("SELECT * FROM tasks WHERE id IN (:ids)")
    suspend fun getTasksByIds(ids: List<String>): List<TaskEntity>

    /** Batch lookup by server ids — returns a Map for O(1) membership in sync fallback lookups. */
    @Query("SELECT * FROM tasks WHERE server_id IN (:serverIds)")
    suspend fun getTasksByServerIds(serverIds: List<Int>): List<TaskEntity>

    @Query("SELECT * FROM tasks WHERE id = :taskId")
    fun getTaskByIdFlow(taskId: String): Flow<TaskEntity?>

    @Query("SELECT * FROM tasks WHERE server_id = :serverId LIMIT 1")
    suspend fun getTaskByServerId(serverId: Int): TaskEntity?

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertTask(task: TaskEntity)

    @Update
    suspend fun updateTask(task: TaskEntity)

    @Delete
    suspend fun deleteTask(task: TaskEntity)

    @Query("DELETE FROM tasks WHERE id = :taskId")
    suspend fun deleteTaskById(taskId: String)

    @Query("UPDATE tasks SET completed_pomodoros = completed_pomodoros + 1, updated_at = :now, is_dirty = 1 WHERE id = :taskId")
    suspend fun incrementPomodoros(taskId: String, now: Long = System.currentTimeMillis())

    /**
     * Mark a task dirty without changing its content. Used when a child subtask is
     * mutated (added/toggled/deleted) so the parent task is included in the next
     * sync push, which carries the up-to-date subtask snapshot.
     */
    @Query("UPDATE tasks SET is_dirty = 1, updated_at = :now WHERE id = :taskId")
    suspend fun markDirty(taskId: String, now: Long = System.currentTimeMillis())

    /**
     * Atomic completion toggle — single SQL statement, no read-modify-write race.
     *
     * `is_completed` on the RHS is the pre-flip value, so:
     *  - currently incomplete (0) → completed_at = :now (we are completing it)
     *  - currently complete (1)   → completed_at = NULL (we are un-completing it)
     */
    @Query(
        """
        UPDATE tasks
        SET is_completed = NOT is_completed,
            completed_at = CASE WHEN is_completed = 0 THEN :now ELSE NULL END,
            is_dirty = 1,
            updated_at = :now
        WHERE id = :taskId
        """,
    )
    suspend fun toggleCompletionAtomic(taskId: String, now: Long = System.currentTimeMillis())

    /** Complete-only: no-op if the task is already completed (idempotent for widget/wear). */
    @Query(
        """
        UPDATE tasks
        SET is_completed = 1,
            completed_at = :now,
            is_dirty = 1,
            updated_at = :now
        WHERE id = :taskId AND is_completed = 0
        """,
    )
    suspend fun completeTaskAtomic(taskId: String, now: Long = System.currentTimeMillis())

    @Query("SELECT COUNT(*) FROM tasks WHERE is_completed = 0 AND is_deleted = 0")
    fun getActiveCount(): Flow<Int>

    @Query("SELECT COUNT(*) FROM tasks WHERE is_completed = 1 AND is_deleted = 0 AND completed_at >= :startOfDay AND completed_at < :endOfDay")
    suspend fun getCompletedTodayCount(startOfDay: Long, endOfDay: Long): Int

    @Query("SELECT * FROM tasks WHERE is_deleted = 0 AND ((due_date >= :startOfDay AND due_date < :endOfDay) OR (is_completed = 1 AND completed_at >= :startOfDay AND completed_at < :endOfDay))")
    suspend fun getTasksForDate(startOfDay: Long, endOfDay: Long): List<TaskEntity>

    // Sync queries
    @Query("SELECT * FROM tasks WHERE is_dirty = 1")
    suspend fun getDirtyTasks(): List<TaskEntity>

    @Query("UPDATE tasks SET is_dirty = 0, synced_at = :syncedAt, server_id = :serverId WHERE id = :taskId")
    suspend fun markSynced(taskId: String, syncedAt: Long, serverId: Int)

    /**
     * Marks many tasks as synced in a single transaction. Each entry carries its own serverId
     * (the server-assigned id varies per task), so we loop internally but commit once.
     * Replaces N separate UPDATE transactions in SyncEngine.
     */
    @Transaction
    suspend fun markSyncedBatch(updates: List<TaskSyncUpdate>, syncedAt: Long) {
        for (u in updates) {
            markSynced(u.taskId, syncedAt, u.serverId)
        }
    }

    @Query("UPDATE tasks SET is_deleted = 1, is_dirty = 1, updated_at = :now WHERE id = :taskId")
    suspend fun softDelete(taskId: String, now: Long = System.currentTimeMillis())

    /** Restore a soft-deleted row in place — preserves serverId and sync metadata. */
    @Query("UPDATE tasks SET is_deleted = 0, is_dirty = 1, updated_at = :now WHERE id = :taskId")
    suspend fun restoreSoftDelete(taskId: String, now: Long = System.currentTimeMillis())

    @Query("DELETE FROM tasks WHERE is_deleted = 1 AND is_dirty = 0")
    suspend fun purgeDeletedSynced()

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsertAll(tasks: List<TaskEntity>)

    @Query("UPDATE tasks SET sort_order = :sortOrder, updated_at = :now, is_dirty = 1 WHERE id = :taskId")
    suspend fun updateSortOrder(taskId: String, sortOrder: Int, now: Long = System.currentTimeMillis())

    @Query("SELECT * FROM tasks ORDER BY created_at DESC")
    suspend fun getAllTasksSync(): List<TaskEntity>

    @Query("SELECT COUNT(*) FROM tasks")
    suspend fun getTaskCount(): Int

    @Query("DELETE FROM tasks")
    suspend fun deleteAll()

    @Query("SELECT COUNT(*) FROM tasks WHERE is_dirty = 1")
    fun getDirtyTaskCount(): Flow<Int>

    /**
     * Apply a batch of sort-order updates inside a single Room transaction.
     *
     * If any individual update fails, the whole batch rolls back so sort ordering
     * never ends up in an inconsistent partial state. All updates share one
     * `updated_at` / `is_dirty` stamp so the synced snapshot is coherent.
     */
    @Transaction
    suspend fun reorderTasksAtomic(updates: List<Pair<String, Int>>) {
        if (updates.isEmpty()) return
        val now = System.currentTimeMillis()
        updates.forEach { (taskId, sortOrder) ->
            updateSortOrder(taskId, sortOrder, now)
        }
    }
}

/** Carrier for batch mark-synced: a task id plus its server-assigned id. */
data class TaskSyncUpdate(
    val taskId: String,
    val serverId: Int,
)
