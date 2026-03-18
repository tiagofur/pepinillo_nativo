package dev.creapolis.pepinillo.data.repository

import android.util.Log
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager
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
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.catch
import kotlinx.coroutines.flow.map
import javax.inject.Inject
import javax.inject.Singleton

private const val TAG = "TaskRepository"

@Singleton
class TaskRepository @Inject constructor(
    private val taskDao: TaskDao,
    private val subtaskDao: SubtaskDao,
    private val focusSessionDao: FocusSessionDao,
    private val workManager: WorkManager,
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
                ),
            )
        }.onFailure { Log.e(TAG, "Error toggling task $taskId", it) }
            .onSuccess { refreshWearData() }

    suspend fun deleteTask(taskId: String): Result<Unit> =
        runCatching { taskDao.deleteTaskById(taskId) }
            .onFailure { Log.e(TAG, "Error deleting task $taskId", it) }
            .onSuccess { refreshWearData() }

    suspend fun getTaskById(taskId: String): Task? =
        runCatching { taskDao.getTaskById(taskId)?.toDomain() }
            .onFailure { Log.e(TAG, "Error getting task $taskId", it) }
            .getOrNull()

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
    private fun refreshWearData() {
        workManager.enqueue(OneTimeWorkRequestBuilder<WidgetRefreshWorker>().build())
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
