package dev.creapolis.pepinillo.appfunctions

import dev.creapolis.pepinillo.core.billing.FeatureGate
import dev.creapolis.pepinillo.data.repository.TaskRepository
import dev.creapolis.pepinillo.feature.tasks.model.MAX_TASK_NOTES_LENGTH
import dev.creapolis.pepinillo.feature.tasks.model.MAX_TASK_TITLE_LENGTH
import dev.creapolis.pepinillo.feature.tasks.model.Task
import kotlinx.coroutines.flow.first
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Gemini-facing task creation logic (issue #912), shared by the
 * [TaskAppFunctionService] binding. Applies the same rules as in-app
 * quick-add ([dev.creapolis.pepinillo.feature.tasks.TasksViewModel.addQuickTask]):
 * trim dictation input, cap lengths, append `sortOrder`, and enforce the
 * free-tier cap of [FeatureGate.FREE_TASK_LIMIT] (issue #216) through the
 * real [FeatureGate] — never duplicating the limit.
 */
@Singleton
class CreateTaskFunction @Inject constructor(
    private val taskRepository: TaskRepository,
    private val featureGate: FeatureGate,
) {

    sealed interface Result {
        data class Created(
            val taskId: String,
            val title: String,
            val notes: String?,
        ) : Result

        data class Rejected(val reason: RejectionReason) : Result
    }

    enum class RejectionReason {
        BLANK_TITLE,
        FREE_TIER_LIMIT,
        STORAGE_ERROR,
    }

    suspend fun invoke(title: String?, notes: String?): Result {
        val trimmedTitle = title?.trim().orEmpty()
        if (trimmedTitle.isEmpty()) return Result.Rejected(RejectionReason.BLANK_TITLE)

        // Authoritative active count (same repository flow the UI gate uses,
        // so tombstones and templates are handled exactly like quick-add).
        val activeCount = taskRepository.getActiveCount().first()
        if (!featureGate.canAddTask(activeCount)) {
            return Result.Rejected(RejectionReason.FREE_TIER_LIMIT)
        }

        val task = Task(
            title = trimmedTitle.take(MAX_TASK_TITLE_LENGTH),
            notes = notes?.trim()?.take(MAX_TASK_NOTES_LENGTH)?.ifBlank { null },
            sortOrder = (taskRepository.getAllTasks().first().maxOfOrNull { it.sortOrder } ?: -1) + 1,
        )
        return taskRepository.addTask(task).fold(
            onSuccess = { Result.Created(task.id, task.title, task.notes) },
            onFailure = { Result.Rejected(RejectionReason.STORAGE_ERROR) },
        )
    }
}
