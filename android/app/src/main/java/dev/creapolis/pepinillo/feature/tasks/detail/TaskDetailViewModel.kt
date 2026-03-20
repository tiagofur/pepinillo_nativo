package dev.creapolis.pepinillo.feature.tasks.detail

import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import dagger.hilt.android.lifecycle.HiltViewModel
import dev.creapolis.pepinillo.data.local.entity.FocusSessionEntity
import dev.creapolis.pepinillo.data.repository.TaskRepository
import dev.creapolis.pepinillo.feature.tasks.model.EnergyLevel
import dev.creapolis.pepinillo.feature.tasks.model.RecurrenceOption
import dev.creapolis.pepinillo.feature.tasks.model.Subtask
import dev.creapolis.pepinillo.feature.tasks.model.Task
import dev.creapolis.pepinillo.feature.tasks.model.TaskPriority
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import javax.inject.Inject

data class TaskDetailUiState(
    val task: Task? = null,
    val subtasks: List<Subtask> = emptyList(),
    val focusSessions: List<FocusSessionEntity> = emptyList(),
    val isLoading: Boolean = true,
    val showDeleteDialog: Boolean = false,
) {
    val subtaskProgress: Pair<Int, Int>
        get() = subtasks.count { it.isCompleted } to subtasks.size

    val totalFocusTimeMillis: Long
        get() = focusSessions.filter { it.phase == null || it.phase == "Work" }.sumOf { it.durationMillis }

    val totalFocusTimeFormatted: String
        get() {
            val totalMinutes = totalFocusTimeMillis / 60_000
            val hours = totalMinutes / 60
            val minutes = totalMinutes % 60
            return if (hours > 0) "${hours}h ${minutes}m" else "${minutes} min"
        }

    val focusPomodoroCount: Int
        get() = focusSessions.count { it.mode.equals("Pomodoro", ignoreCase = true) && (it.phase == null || it.phase == "Work") }
}

@HiltViewModel
class TaskDetailViewModel @Inject constructor(
    savedStateHandle: SavedStateHandle,
    private val taskRepository: TaskRepository,
) : ViewModel() {

    private val taskId: String = checkNotNull(savedStateHandle["taskId"])

    private val _showDeleteDialog = MutableStateFlow(false)

    private val _navigateBack = MutableSharedFlow<Unit>()
    val navigateBack: SharedFlow<Unit> = _navigateBack.asSharedFlow()

    private val _errorEvent = MutableSharedFlow<String>()
    val errorEvent: SharedFlow<String> = _errorEvent.asSharedFlow()

    val uiState: StateFlow<TaskDetailUiState> = combine(
        taskRepository.getTaskByIdFlow(taskId),
        taskRepository.getSubtasksForTask(taskId),
        taskRepository.getSessionsForTask(taskId),
        _showDeleteDialog,
    ) { task, subtasks, sessions, showDelete ->
        TaskDetailUiState(
            task = task,
            subtasks = subtasks,
            focusSessions = sessions,
            isLoading = false,
            showDeleteDialog = showDelete,
        )
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), TaskDetailUiState())

    private inline fun updateTask(crossinline transform: (Task) -> Task) {
        val current = uiState.value.task ?: return
        viewModelScope.launch {
            taskRepository.updateTask(transform(current)).onFailure {
                _errorEvent.emit("Failed to update task")
            }
        }
    }

    fun updateTitle(title: String) = updateTask { it.copy(title = title) }
    fun updateNotes(notes: String) = updateTask { it.copy(notes = notes.ifBlank { null }) }
    fun updatePriority(priority: TaskPriority) = updateTask { it.copy(priority = priority) }
    fun updateEnergyLevel(level: EnergyLevel) = updateTask { it.copy(energyLevel = level) }
    fun updateEstimatedPomodoros(count: Int) = updateTask { it.copy(estimatedPomodoros = count.coerceIn(1, 8)) }
    fun updateDueDate(millis: Long?) = updateTask { it.copy(dueDate = millis) }
    fun toggleScheduledForToday() = updateTask { it.copy(scheduledForToday = !it.scheduledForToday) }
    fun updateRecurrence(option: RecurrenceOption) = updateTask { it.copy(recurrenceRule = option.rrule) }

    fun toggleCompletion() {
        viewModelScope.launch {
            taskRepository.toggleCompletion(taskId).onFailure {
                _errorEvent.emit("Failed to update task")
            }
        }
    }

    // ── Subtasks ──

    fun addSubtask(title: String) {
        if (title.isBlank()) return
        viewModelScope.launch {
            taskRepository.addSubtask(taskId, title.trim()).onFailure {
                _errorEvent.emit("Failed to add subtask")
            }
        }
    }

    fun toggleSubtask(subtaskId: String) = viewModelScope.launch {
        taskRepository.toggleSubtask(subtaskId).onFailure {
            _errorEvent.emit("Failed to update subtask")
        }
    }

    fun deleteSubtask(subtaskId: String) = viewModelScope.launch {
        taskRepository.deleteSubtask(subtaskId).onFailure {
            _errorEvent.emit("Failed to delete subtask")
        }
    }

    // ── Delete ──

    fun showDeleteDialog() { _showDeleteDialog.value = true }
    fun dismissDeleteDialog() { _showDeleteDialog.value = false }

    fun confirmDelete() {
        viewModelScope.launch {
            taskRepository.deleteTask(taskId).onFailure {
                _errorEvent.emit("Failed to delete task")
            }
            _showDeleteDialog.value = false
            _navigateBack.emit(Unit)
        }
    }
}
