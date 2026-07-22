package dev.creapolis.pepinillo.data.repository

import android.content.Context
import android.util.Log
import androidx.work.ExistingWorkPolicy
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager
import dagger.hilt.android.qualifiers.ApplicationContext
import dev.creapolis.pepinillo.di.ApplicationScope
import dev.creapolis.pepinillo.data.local.dao.FocusSessionDao
import dev.creapolis.pepinillo.data.local.dao.SubtaskDao
import dev.creapolis.pepinillo.data.local.dao.TaskDao
import dev.creapolis.pepinillo.data.local.entity.FocusSessionEntity
import dev.creapolis.pepinillo.data.local.entity.SubtaskEntity
import dev.creapolis.pepinillo.data.local.entity.TaskEntity
import dev.creapolis.pepinillo.core.billing.FeatureGate
import dev.creapolis.pepinillo.data.sync.WidgetRefreshWorker
import dev.creapolis.pepinillo.domain.streak.StreakProtectionService
import dev.creapolis.pepinillo.domain.tasks.RecurrenceCalculator

import dev.creapolis.pepinillo.feature.tasks.model.EnergyLevel
import dev.creapolis.pepinillo.feature.tasks.model.Subtask
import dev.creapolis.pepinillo.feature.tasks.model.Task
import dev.creapolis.pepinillo.feature.tasks.model.TaskPriority
import dev.creapolis.pepinillo.wear.WearDataLayerHelper
import dev.creapolis.pepinillo.widget.WidgetTask
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.launch
import kotlinx.coroutines.flow.catch
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.isActive
import java.util.Calendar
import javax.inject.Inject
import javax.inject.Singleton

private const val TAG = "TaskRepository"

/** Debounce window for Wear/widget refreshes after a task mutation burst (e.g. typing). */
private const val REFRESH_DEBOUNCE_MS = 400L

/** Unique-work name so a burst of widget-refresh requests collapses into one run. */
private const val WIDGET_REFRESH_WORK = "pepinillo_widget_refresh"

@Singleton
class TaskRepository @Inject constructor(
    private val taskDao: TaskDao,
    private val subtaskDao: SubtaskDao,
    private val focusSessionDao: FocusSessionDao,
    private val workManager: WorkManager,
    private val sessionRepository: SessionRepository,
    private val featureGate: FeatureGate,
    @ApplicationContext private val appContext: Context,
    @ApplicationScope private val appScope: CoroutineScope,
) {
    /** Coalesces rapid refreshWearData calls (e.g. one per keystroke) into a single execution. */
    private val refreshTrigger = kotlinx.coroutines.channels.Channel<Unit>(
        capacity = kotlinx.coroutines.channels.Channel.CONFLATED,
    )

    init {
        // Drain rapid refresh requests (e.g. one per keystroke in task title/notes) into a single
        // Wear + widget push, debounced so we don't reload all active tasks + history per keystroke.
        appScope.launch {
            for (signal in refreshTrigger) {
                performWearAndWidgetRefresh()
                // Coalesce bursts: a tiny delay absorbs trailing keystrokes that arrive while we work.
                delay(REFRESH_DEBOUNCE_MS)
            }
        }
    }
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
            val existing = taskDao.getTaskById(task.id)
                ?: error("Task ${task.id} not found")
            val now = System.currentTimeMillis()
            taskDao.updateTask(task.mergeInto(existing, now))
        }
            .onFailure { Log.e(TAG, "Error updating task ${task.id}", it) }
            .onSuccess { refreshWearData() }

    suspend fun toggleCompletion(taskId: String): Result<Unit> =
        runCatching {
            val entity = taskDao.getTaskById(taskId) ?: error("Task $taskId not found")
            val completing = !entity.isCompleted
            val hasRecurrence = !entity.recurrenceRule.isNullOrBlank()

            if (completing && hasRecurrence && featureGate.canUseRecurrence()) {
                advanceRecurringTask(entity)
            } else {
                // Atomic single-statement UPDATE — no read-modify-write race for plain toggles.
                taskDao.toggleCompletionAtomic(taskId)
            }
        }.onFailure { Log.e(TAG, "Error toggling task $taskId", it) }
            .onSuccess { refreshWearData() }

    /**
     * Complete-only path for widget/wear — idempotent (already-completed tasks succeed without toggling back).
     */
    suspend fun completeTaskFromWear(taskId: String): Result<Unit> =
        runCatching {
            val entity = taskDao.getTaskById(taskId) ?: error("Task $taskId not found")
            if (entity.isCompleted) return@runCatching

            val hasRecurrence = !entity.recurrenceRule.isNullOrBlank()
            if (hasRecurrence && featureGate.canUseRecurrence()) {
                advanceRecurringTask(entity)
            } else {
                taskDao.completeTaskAtomic(taskId)
            }
        }.onFailure { Log.e(TAG, "Error completing task $taskId from wear/widget", it) }
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

    /** Restore a previously soft-deleted task without domain round-trip (preserves serverId). */
    suspend fun restoreTask(task: Task): Result<Unit> =
        runCatching {
            taskDao.restoreSoftDelete(task.id)
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
     * Each pair is (taskId, newSortOrder). Applied atomically — partial failure
     * rolls the whole batch back so sort order never ends up inconsistent.
     */
    suspend fun reorderTasks(orderedIds: List<Pair<String, Int>>): Result<Unit> =
        runCatching {
            taskDao.reorderTasksAtomic(orderedIds)
        }
            .onFailure { Log.e(TAG, "Error reordering tasks", it) }
            .onSuccess { refreshWearData() }

    suspend fun incrementPomodoros(taskId: String) {
        runCatching { taskDao.incrementPomodoros(taskId) }
            .onFailure { Log.e(TAG, "Error incrementing pomodoros for $taskId", it) }
    }

    suspend fun getCompletedTodayCount(startOfDay: Long, endOfDay: Long = SessionRepository.addDays(startOfDay, 1)): Int =
        runCatching { taskDao.getCompletedTodayCount(startOfDay, endOfDay) }
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
            // Mark parent dirty so the next sync push carries the new subtask in the
            // task's snapshot — otherwise the local-only subtask is lost on merge.
            taskDao.markDirty(taskId)
        }.onFailure { Log.e(TAG, "Error adding subtask", it) }

    suspend fun toggleSubtask(subtaskId: String): Result<Unit> =
        runCatching {
            subtaskDao.toggleCompletion(subtaskId)
            // Propagate dirtiness to the parent so the toggle survives the next sync.
            val parentId = subtaskDao.getTaskIdForSubtask(subtaskId)
            if (parentId != null) taskDao.markDirty(parentId)
        }
            .onFailure { Log.e(TAG, "Error toggling subtask $subtaskId", it) }

    suspend fun deleteSubtask(subtaskId: String): Result<Unit> =
        runCatching {
            // Resolve parent first (soft-delete keeps the row, but capturing the id
            // up-front is clearer and avoids any ordering surprise).
            val parentId = subtaskDao.getTaskIdForSubtask(subtaskId)
            subtaskDao.deleteSubtaskById(subtaskId)
            if (parentId != null) taskDao.markDirty(parentId)
        }
            .onFailure { Log.e(TAG, "Error deleting subtask $subtaskId", it) }

    // ── Focus session methods ──

    fun getSessionsForTask(taskId: String): Flow<List<FocusSessionEntity>> =
        focusSessionDao.getSessionsForTask(taskId)
            .catch { e -> Log.e(TAG, "Error loading sessions for $taskId", e); emit(emptyList()) }

    /** Signal a Wear + widget refresh. Coalesced and debounced — safe to call per keystroke. */
    private fun refreshWearData() {
        refreshTrigger.trySend(Unit)
    }

    /** Actual Wear + widget push. Runs once per burst, off the call site's coroutine. */
    /**
     * Completing a recurring task advances due/nextOccurrence and keeps the row active
     * instead of leaving it in Completed (series must not die on first complete).
     */
    private suspend fun advanceRecurringTask(entity: TaskEntity) {
        val rule = entity.recurrenceRule ?: return
        val now = System.currentTimeMillis()
        val today = RecurrenceCalculator.startOfLocalDay(now)
        val reference = entity.dueDate?.let { maxOf(it, today.timeInMillis) } ?: today.timeInMillis
        val nextDue = RecurrenceCalculator.nextOccurrenceMillis(rule, reference)
        val scheduledForToday = RecurrenceCalculator.isSameLocalDay(nextDue, today)

        taskDao.updateTask(
            entity.copy(
                isCompleted = false,
                completedAt = null,
                dueDate = nextDue,
                nextOccurrence = nextDue,
                isRecurringTemplate = true,
                scheduledForToday = scheduledForToday,
                updatedAt = now,
                isDirty = true,
            ),
        )
    }

    private suspend fun performWearAndWidgetRefresh() {
        // Widgets via WorkManager — unique + KEEP so a burst collapses into one pending run.
        workManager.enqueueUniqueWork(
            WIDGET_REFRESH_WORK,
            ExistingWorkPolicy.KEEP,
            OneTimeWorkRequestBuilder<WidgetRefreshWorker>().build(),
        )

        // Wear direct push (WorkManager doesn't reach the watch).
        runCatching {
            val activeTasks = taskDao.getActiveTasks().first().map { it.toDomain() }
            val widgetTasks = activeTasks.take(5).map { WidgetTask.fromTask(it) }
            val stats = sessionRepository.getTodayStats().first()
            val allDays = sessionRepository.getAllDaysWithSessions().first()
            val streak = StreakProtectionService.computeProtectedStreak(
                history = allDays,
                isPro = featureGate.isPro,
            ).days
            val cal = Calendar.getInstance().apply {
                set(Calendar.HOUR_OF_DAY, 0); set(Calendar.MINUTE, 0)
                set(Calendar.SECOND, 0); set(Calendar.MILLISECOND, 0)
            }
            val dayStart = cal.timeInMillis
            val completedToday = taskDao.getCompletedTodayCount(dayStart, SessionRepository.addDays(dayStart, 1))
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

/**
 * Merge domain fields from [Task] onto an existing [TaskEntity], preserving sync metadata
 * (serverId, syncedAt, isDeleted) and entity-only columns (nextOccurrence) that the
 * domain model does not carry. Room @Update overwrites every column, so defaults from
 * [toEntity] would otherwise wipe server linkage after a local edit.
 */
private fun Task.mergeInto(existing: TaskEntity, updatedAt: Long = System.currentTimeMillis()): TaskEntity {
    val recurrenceAdded = recurrenceRule != null && existing.recurrenceRule == null
    val recurrenceCleared = recurrenceRule == null && existing.recurrenceRule != null
    val nextOccurrence = when {
        recurrenceCleared -> null
        recurrenceAdded && recurrenceRule != null ->
            RecurrenceCalculator.nextOccurrenceMillis(
                recurrenceRule,
                dueDate ?: RecurrenceCalculator.startOfLocalDay().timeInMillis,
            )
        else -> existing.nextOccurrence
    }

    return TaskEntity(
        id = id,
        title = title,
        notes = notes,
        // Completion is owned by toggleCompletion — detail edits must not clobber it.
        isCompleted = existing.isCompleted,
        completedAt = existing.completedAt,
        energyLevel = energyLevel.name,
        priority = priority.name,
        estimatedPomodoros = estimatedPomodoros,
        completedPomodoros = completedPomodoros,
        sortOrder = sortOrder,
        dueDate = dueDate,
        scheduledForToday = scheduledForToday,
        recurrenceRule = recurrenceRule,
        nextOccurrence = nextOccurrence,
        isRecurringTemplate = recurrenceRule != null,
        recurringTemplateID = recurringTemplateID,
        createdAt = createdAt,
        updatedAt = updatedAt,
        serverId = existing.serverId,
        isDirty = true,
        isDeleted = existing.isDeleted,
        syncedAt = existing.syncedAt,
    )
}

private fun SubtaskEntity.toDomain() = Subtask(
    id = id,
    title = title,
    isCompleted = isCompleted,
    sortOrder = sortOrder,
)
