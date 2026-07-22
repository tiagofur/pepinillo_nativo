package dev.creapolis.pepinillo.feature.tasks.detail

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import dagger.hilt.android.lifecycle.HiltViewModel
import dev.creapolis.pepinillo.data.local.entity.FocusSessionEntity
import dev.creapolis.pepinillo.core.billing.FeatureGate
import dev.creapolis.pepinillo.data.repository.TaskRepository
import dev.creapolis.pepinillo.feature.tasks.model.EnergyLevel
import dev.creapolis.pepinillo.feature.tasks.model.RecurrenceOption
import dev.creapolis.pepinillo.feature.tasks.model.Subtask
import dev.creapolis.pepinillo.feature.tasks.model.Task
import dev.creapolis.pepinillo.feature.tasks.model.TaskPriority
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.flatMapLatest
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import javax.inject.Inject

data class TaskDetailUiState(
    val task: Task? = null,
    val subtasks: List<Subtask> = emptyList(),
    val focusSessions: List<FocusSessionEntity> = emptyList(),
    val isLoading: Boolean = true,
    val showDeleteDialog: Boolean = false,
    val isPro: Boolean = false,
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

@OptIn(ExperimentalCoroutinesApi::class)
@HiltViewModel
class TaskDetailViewModel @Inject constructor(
    private val taskRepository: TaskRepository,
    private val featureGate: FeatureGate,
) : ViewModel() {

    // taskId is set via initialize() after Hilt constructs the ViewModel
    private val _taskId = MutableStateFlow<String?>(null)
    private val taskIdFlow: StateFlow<String?> = _taskId.asStateFlow()

    /** Must be called once after obtaining the ViewModel instance. */
    fun initialize(taskId: String) {
        if (_taskId.value == null) {
            _taskId.value = taskId
        }
    }

    private val currentTaskId: String
        get() = _taskId.value ?: error("TaskDetailViewModel.initialize() was not called")

    private val _showDeleteDialog = MutableStateFlow(false)

    private val _showPaywall = MutableStateFlow(false)
    val showPaywall: StateFlow<Boolean> = _showPaywall.asStateFlow()

    val isPro: Boolean get() = featureGate.isPro

    private val _navigateBack = MutableSharedFlow<Unit>()
    val navigateBack: SharedFlow<Unit> = _navigateBack.asSharedFlow()

    private val _errorEvent = MutableSharedFlow<String>()
    val errorEvent: SharedFlow<String> = _errorEvent.asSharedFlow()

    private val updateMutex = Mutex()

    val uiState: StateFlow<TaskDetailUiState> = taskIdFlow
        .flatMapLatest { id ->
            if (id == null) {
                flowOf(TaskDetailUiState())
            } else {
                combine(
                    taskRepository.getTaskByIdFlow(id),
                    taskRepository.getSubtasksForTask(id),
                    taskRepository.getSessionsForTask(id),
                    _showDeleteDialog,
                    featureGate.subscriptionState,
                ) { task, subtasks, sessions, showDelete, subState ->
                    TaskDetailUiState(
                        task = task,
                        subtasks = subtasks,
                        focusSessions = sessions,
                        isLoading = false,
                        showDeleteDialog = showDelete,
                        isPro = subState.hasLocalPremium,
                    )
                }
            }
        }
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), TaskDetailUiState())

    private inline fun updateTask(crossinline transform: (Task) -> Task) {
        val taskId = currentTaskId
        viewModelScope.launch {
            updateMutex.withLock {
                val latest = taskRepository.getTaskById(taskId) ?: return@withLock
                taskRepository.updateTask(transform(latest)).onFailure {
                    _errorEvent.emit("Failed to update task")
                }
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
    fun updateRecurrence(option: RecurrenceOption) {
        if (option != RecurrenceOption.None && !featureGate.canUseRecurrence()) {
            _showPaywall.value = true
            return
        }
        updateTask {
            it.copy(
                recurrenceRule = option.rrule,
                isRecurringTemplate = option != RecurrenceOption.None,
            )
        }
    }

    fun toggleCompletion() {
        viewModelScope.launch {
            taskRepository.toggleCompletion(currentTaskId).onFailure {
                _errorEvent.emit("Failed to update task")
            }
        }
    }

    // ── Subtasks ──

    fun addSubtask(title: String) {
        if (title.isBlank()) return
        if (!featureGate.canUseSubtasks()) {
            _showPaywall.value = true
            return
        }
        viewModelScope.launch {
            taskRepository.addSubtask(currentTaskId, title.trim()).onFailure {
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

    // ── Paywall ──

    fun dismissPaywall() { _showPaywall.value = false }

    // ── Delete ──

    fun showDeleteDialog() { _showDeleteDialog.value = true }
    fun dismissDeleteDialog() { _showDeleteDialog.value = false }

    fun confirmDelete() {
        viewModelScope.launch {
            taskRepository.deleteTask(currentTaskId).onFailure {
                _errorEvent.emit("Failed to delete task")
            }
            _showDeleteDialog.value = false
            _navigateBack.emit(Unit)
        }
    }
}
