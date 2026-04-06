package dev.creapolis.pepinillo.data.repository

import android.content.Context
import android.util.Log
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager
import dagger.hilt.android.qualifiers.ApplicationContext
import dev.creapolis.pepinillo.data.local.dao.FocusSessionDao
import dev.creapolis.pepinillo.data.local.dao.SubtaskDao
import dev.creapolis.pepinillo.data.local.dao.TaskDao
import dev.creapolis.pepinillo.data.local.entity.FocusSessionEntity
import dev.creapolis.pepinillo.data.local.entity.SubtaskEntity
import dev.creapolis.pepinillo.data.local.entity.TaskEntity
import dev.creapolis.pepinillo.data.sync.WidgetRefreshWorker
import dev.creapolis.pepinillo.feature.tasks.model.EnergyLevel
import dev.creapolis.pepinillo.feature.tasks.model.Subtask
import dev.creapolis.pepinillo.feature.tasks.model.Task
import dev.creapolis.pepinillo.feature.tasks.model.TaskPriority
import dev.creapolis.pepinillo.wear.WearDataLayerHelper
import dev.creapolis.pepinillo.widget.WidgetTask
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.catch
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map
import java.util.Calendar
import javax.inject.Inject
import javax.inject.Singleton

private const val TAG = "TaskRepository"

@Singleton
class TaskRepository @Inject constructor(
    private val taskDao: TaskDao,
    private val subtaskDao: SubtaskDao,
    private val focusSessionDao: FocusSessionDao,
    private val workManager: WorkManager,
    private val sessionRepository: SessionRepository,
    @ApplicationContext private val appContext: Context,
) {
    fun getAllTasks(): Flow<List<Task>> =
        taskDao.getAllTasks()
            .map { entities -> entities.map { it.toDomain() } }
            .catch { e -> Log.e(TAG, "Error loading all tasks", e); emit(emptyList()) }

    fun getActiveTasks(): Flow<List<Task>> =
        taskDao.getActiveTasks()
            .map { entities -> entities.map { it.toDomain() } }
            .catch { e -> Log.e(TAG, "Error loading active tasks", e); emit(emptyList()) }

    fun getCompletedTasks(): Flow<List<Task>> =
        taskDao.getCompletedTasks()
            .map { entities -> entities.map { it.toDomain() } }
            .catch { e -> Log.e(TAG, "Error loading completed tasks", e); emit(emptyList()) }

    fun getActiveCount(): Flow<Int> =
        taskDao.getActiveCount()
            .catch { e -> Log.e(TAG, "Error loading active count", e); emit(0) }

    fun getTaskByIdFlow(taskId: String): Flow<Task?> =
        taskDao.getTaskByIdFlow(taskId)
            .map { it?.toDomain() }
            .catch { e -> Log.e(TAG, "Error loading task $taskId", e); emit(null) }

    suspend fun addTask(task: Task): Result<Unit> =
        runCatching { taskDao.insertTask(task.toEntity()) }
            .onFailure { Log.e(TAG, "Error adding task", it) }
            .onSuccess { refreshWearData() }

    suspend fun updateTask(task: Task): Result<Unit> =
        runCatching {
            taskDao.updateTask(task.toEntity().copy(updatedAt = System.currentTimeMillis(), isDirty = true))
        }
            .onFailure { Log.e(TAG, "Error updating task ${task.id}", it) }
            .onSuccess { refreshWearData() }

    suspend fun toggleCompletion(taskId: String): Result<Unit> =
        runCatching {
            val entity = taskDao.getTaskById(taskId)
                ?: throw IllegalStateException("Task $taskId not found")
            taskDao.updateTask(
                entity.copy(
                    isCompleted = !entity.isCompleted,
                    completedAt = if (!entity.isCompleted) System.currentTimeMillis() else null,
                    updatedAt = System.currentTimeMillis(),
                    isDirty = true,
                ),
            )
        }.onFailure { Log.e(TAG, "Error toggling task $taskId", it) }
            .onSuccess { refreshWearData() }

    suspend fun deleteTask(taskId: String): Result<Unit> =
        runCatching { taskDao.softDelete(taskId) }
            .onFailure { Log.e(TAG, "Error deleting task $taskId", it) }
            .onSuccess { refreshWearData() }

    /** Soft-delete: marks task as deleted and returns it so it can be restored via undo. */
    suspend fun deleteTaskWithUndo(taskId: String): Result<Task?> =
        runCatching {
            val entity = taskDao.getTaskById(taskId)
            val task = entity?.toDomain()
            if (entity != null) taskDao.softDelete(taskId)
            task
        }
            .onFailure { Log.e(TAG, "Error deleting task $taskId", it) }
            .onSuccess { refreshWearData() }

    /** Restore a previously soft-deleted task. */
    suspend fun restoreTask(task: Task): Result<Unit> =
        runCatching {
            val entity = task.toEntity().copy(
                isDeleted = false,
                isDirty = true,
                updatedAt = System.currentTimeMillis(),
            )
            taskDao.insertTask(entity)
        }
            .onFailure { Log.e(TAG, "Error restoring task ${task.id}", it) }
            .onSuccess { refreshWearData() }

    suspend fun getTaskById(taskId: String): Task? =
        runCatching { taskDao.getTaskById(taskId)?.toDomain() }
            .onFailure { Log.e(TAG, "Error getting task $taskId", it) }
            .getOrNull()

    suspend fun getTaskTitle(taskId: String): String =
        getTaskById(taskId)?.title ?: "Unknown Task"

    /**
     * Batch-update sort orders for a reordered list of tasks.
     * Each pair is (taskId, newSortOrder).
     */
    suspend fun reorderTasks(orderedIds: List<Pair<String, Int>>): Result<Unit> =
        runCatching {
            orderedIds.forEach { (id, order) ->
                taskDao.updateSortOrder(id, order)
            }
        }
            .onFailure { Log.e(TAG, "Error reordering tasks", it) }
            .onSuccess { refreshWearData() }

    suspend fun incrementPomodoros(taskId: String) {
        runCatching { taskDao.incrementPomodoros(taskId) }
            .onFailure { Log.e(TAG, "Error incrementing pomodoros for $taskId", it) }
    }

    suspend fun getCompletedTodayCount(startOfDay: Long): Int =
        runCatching { taskDao.getCompletedTodayCount(startOfDay) }
            .onFailure { Log.e(TAG, "Error counting completed tasks today", it) }
            .getOrDefault(0)

    // ── Subtask methods ──

    fun getSubtasksForTask(taskId: String): Flow<List<Subtask>> =
        subtaskDao.getSubtasksForTask(taskId)
            .map { entities -> entities.map { it.toDomain() } }
            .catch { e -> Log.e(TAG, "Error loading subtasks for $taskId", e); emit(emptyList()) }

    suspend fun addSubtask(taskId: String, title: String): Result<Unit> =
        runCatching {
            subtaskDao.insertSubtask(
                SubtaskEntity(
                    taskId = taskId,
                    title = title,
                ),
            )
        }.onFailure { Log.e(TAG, "Error adding subtask", it) }

    suspend fun toggleSubtask(subtaskId: String): Result<Unit> =
        runCatching { subtaskDao.toggleCompletion(subtaskId) }
            .onFailure { Log.e(TAG, "Error toggling subtask $subtaskId", it) }

    suspend fun deleteSubtask(subtaskId: String): Result<Unit> =
        runCatching { subtaskDao.deleteSubtaskById(subtaskId) }
            .onFailure { Log.e(TAG, "Error deleting subtask $subtaskId", it) }

    // ── Focus session methods ──

    fun getSessionsForTask(taskId: String): Flow<List<FocusSessionEntity>> =
        focusSessionDao.getSessionsForTask(taskId)
            .catch { e -> Log.e(TAG, "Error loading sessions for $taskId", e); emit(emptyList()) }

    /** Push updated task list to Wear and widgets immediately. */
    private suspend fun refreshWearData() {
        // Widgets via WorkManager
        workManager.enqueue(OneTimeWorkRequestBuilder<WidgetRefreshWorker>().build())

        // Wear direct push (WorkManager fails for wear)
        runCatching {
            val activeTasks = taskDao.getActiveTasks().first().map { it.toDomain() }
            val widgetTasks = activeTasks.take(5).map { WidgetTask.fromTask(it) }
            val stats = sessionRepository.getTodayStats().first()
            val allDays = sessionRepository.getAllDaysWithSessions().first()
            val streak = sessionRepository.calculateCurrentStreak(allDays)
            val cal = Calendar.getInstance().apply {
                set(Calendar.HOUR_OF_DAY, 0); set(Calendar.MINUTE, 0)
                set(Calendar.SECOND, 0); set(Calendar.MILLISECOND, 0)
            }
            val completedToday = taskDao.getCompletedTodayCount(cal.timeInMillis)
            WearDataLayerHelper.pushTasksAndStats(
                context = appContext,
                tasks = widgetTasks,
                totalMinutes = stats?.totalMinutes ?: 0,
                sessions = stats?.sessionsCompleted ?: 0,
                streak = streak,
                completedTasksToday = completedToday,
            )
        }.onFailure { e ->
            Log.e(TAG, "Wear direct push failed", e)
        }
    }
}

private fun TaskEntity.toDomain() = Task(
    id = id,
    title = title,
    notes = notes,
    isCompleted = isCompleted,
    completedAt = completedAt,
    energyLevel = try { EnergyLevel.valueOf(energyLevel) } catch (_: Exception) { EnergyLevel.Regular },
    priority = try { TaskPriority.valueOf(priority) } catch (_: Exception) { TaskPriority.None },
    estimatedPomodoros = estimatedPomodoros,
    completedPomodoros = completedPomodoros,
    sortOrder = sortOrder,
    dueDate = dueDate,
    scheduledForToday = scheduledForToday,
    recurrenceRule = recurrenceRule,
    isRecurringTemplate = isRecurringTemplate,
    recurringTemplateID = recurringTemplateID,
    createdAt = createdAt,
)

private fun Task.toEntity() = TaskEntity(
    id = id,
    title = title,
    notes = notes,
    isCompleted = isCompleted,
    completedAt = completedAt,
    energyLevel = energyLevel.name,
    priority = priority.name,
    estimatedPomodoros = estimatedPomodoros,
    completedPomodoros = completedPomodoros,
    sortOrder = sortOrder,
    dueDate = dueDate,
    scheduledForToday = scheduledForToday,
    recurrenceRule = recurrenceRule,
    isRecurringTemplate = isRecurringTemplate,
    recurringTemplateID = recurringTemplateID,
    createdAt = createdAt,
)

private fun SubtaskEntity.toDomain() = Subtask(
    id = id,
    title = title,
    isCompleted = isCompleted,
    sortOrder = sortOrder,
)
