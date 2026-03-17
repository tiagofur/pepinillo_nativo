package dev.creapolis.pepinillo.data.repository

import dev.creapolis.pepinillo.data.local.dao.TaskDao
import dev.creapolis.pepinillo.data.local.entity.TaskEntity
import dev.creapolis.pepinillo.feature.tasks.model.EnergyLevel
import dev.creapolis.pepinillo.feature.tasks.model.Task
import dev.creapolis.pepinillo.feature.tasks.model.TaskPriority
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class TaskRepository @Inject constructor(
    private val taskDao: TaskDao,
) {
    fun getAllTasks(): Flow<List<Task>> =
        taskDao.getAllTasks().map { entities -> entities.map { it.toDomain() } }

    fun getActiveTasks(): Flow<List<Task>> =
        taskDao.getActiveTasks().map { entities -> entities.map { it.toDomain() } }

    fun getCompletedTasks(): Flow<List<Task>> =
        taskDao.getCompletedTasks().map { entities -> entities.map { it.toDomain() } }

    fun getActiveCount(): Flow<Int> = taskDao.getActiveCount()

    suspend fun addTask(task: Task) {
        taskDao.insertTask(task.toEntity())
    }

    suspend fun toggleCompletion(taskId: String) {
        val entity = taskDao.getTaskById(taskId) ?: return
        taskDao.updateTask(
            entity.copy(
                isCompleted = !entity.isCompleted,
                completedAt = if (!entity.isCompleted) System.currentTimeMillis() else null,
                updatedAt = System.currentTimeMillis(),
            ),
        )
    }

    suspend fun deleteTask(taskId: String) {
        taskDao.deleteTaskById(taskId)
    }

    suspend fun incrementPomodoros(taskId: String) {
        taskDao.incrementPomodoros(taskId)
    }
}

private fun TaskEntity.toDomain() = Task(
    id = id,
    title = title,
    isCompleted = isCompleted,
    energyLevel = try { EnergyLevel.valueOf(energyLevel) } catch (_: Exception) { EnergyLevel.Regular },
    priority = try { TaskPriority.valueOf(priority) } catch (_: Exception) { TaskPriority.None },
    estimatedPomodoros = estimatedPomodoros,
    completedPomodoros = completedPomodoros,
)

private fun Task.toEntity() = TaskEntity(
    id = id,
    title = title,
    isCompleted = isCompleted,
    energyLevel = energyLevel.name,
    priority = priority.name,
    estimatedPomodoros = estimatedPomodoros,
    completedPomodoros = completedPomodoros,
)
