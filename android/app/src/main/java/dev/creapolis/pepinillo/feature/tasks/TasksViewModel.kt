package dev.creapolis.pepinillo.feature.tasks

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import dagger.hilt.android.lifecycle.HiltViewModel
import dev.creapolis.pepinillo.core.billing.FeatureGate
import dev.creapolis.pepinillo.data.repository.TaskRepository
import dev.creapolis.pepinillo.feature.tasks.model.EnergyLevel
import dev.creapolis.pepinillo.feature.tasks.model.Task
import dev.creapolis.pepinillo.feature.tasks.model.TaskPriority
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import javax.inject.Inject

enum class TaskFilter(val label: String) {
    Today("Today"),
    Active("Active"),
    Completed("Done"),
    All("All"),
}

enum class TaskSortOption(val label: String) {
    Custom("Custom"),
    Priority("Priority"),
    DueDate("Due Date"),
    Energy("Energy"),
    Newest("Newest"),
}

data class TasksUiState(
    val tasks: List<Task> = emptyList(),
    val selectedFilter: TaskFilter = TaskFilter.All,
    val selectedSort: TaskSortOption = TaskSortOption.Custom,
    val energyFilter: EnergyLevel? = null,
    val isLoading: Boolean = true,
    val isPro: Boolean = false,
)

val TasksUiState.filteredTasks: List<Task>
    get() {
        // 1. Status filter
        val statusFiltered = when (selectedFilter) {
            TaskFilter.Today -> tasks.filter { !it.isCompleted && it.scheduledForToday }
            TaskFilter.Active -> tasks.filter { !it.isCompleted }
            TaskFilter.Completed -> tasks.filter { it.isCompleted }
            TaskFilter.All -> tasks
        }
        // 2. Energy filter
        val energyFiltered = if (energyFilter != null) {
            statusFiltered.filter { it.energyLevel == energyFilter }
        } else {
            statusFiltered
        }
        // 3. Sort
        return when (selectedSort) {
            TaskSortOption.Custom -> energyFiltered.sortedWith(
                compareBy<Task> { it.isCompleted }.thenBy { it.sortOrder }.thenByDescending { it.createdAt },
            )
            TaskSortOption.Priority -> energyFiltered.sortedWith(
                compareBy<Task> { it.isCompleted }.thenBy { priorityOrdinal(it.priority) }.thenByDescending { it.createdAt },
            )
            TaskSortOption.DueDate -> energyFiltered.sortedWith(
                compareBy<Task> { it.isCompleted }.thenBy(nullsLast()) { it.dueDate }.thenByDescending { it.createdAt },
            )
            TaskSortOption.Energy -> energyFiltered.sortedWith(
                compareBy<Task> { it.isCompleted }.thenBy { it.energyLevel.ordinal }.thenByDescending { it.createdAt },
            )
            TaskSortOption.Newest -> energyFiltered.sortedWith(
                compareBy<Task> { it.isCompleted }.thenByDescending { it.createdAt },
            )
        }
    }

private fun priorityOrdinal(p: TaskPriority) = when (p) {
    TaskPriority.High -> 0
    TaskPriority.Medium -> 1
    TaskPriority.Low -> 2
    TaskPriority.None -> 3
}

val TasksUiState.activeCount: Int
    get() = tasks.count { !it.isCompleted }

@HiltViewModel
class TasksViewModel @Inject constructor(
    private val taskRepository: TaskRepository,
    private val featureGate: FeatureGate,
) : ViewModel() {

    private val _selectedFilter = MutableStateFlow(TaskFilter.All)
    private val _selectedSort = MutableStateFlow(TaskSortOption.Custom)
    private val _energyFilter = MutableStateFlow<EnergyLevel?>(null)
    private val _showPaywall = MutableStateFlow(false)
    val showPaywall: StateFlow<Boolean> = _showPaywall.asStateFlow()

    private val _errorEvent = MutableSharedFlow<String>()
    val errorEvent: SharedFlow<String> = _errorEvent.asSharedFlow()

    private val _undoEvent = MutableStateFlow<UndoState?>(null)
    val undoEvent: StateFlow<UndoState?> = _undoEvent.asStateFlow()
    private var undoExpiryJob: Job? = null

    private val _successMessage = MutableStateFlow<String?>(null)
    val successMessage: StateFlow<String?> = _successMessage.asStateFlow()
    fun dismissSuccessMessage() { _successMessage.value = null }

    val uiState: StateFlow<TasksUiState> = combine(
        taskRepository.getAllTasks(),
        _selectedFilter,
        _selectedSort,
        _energyFilter,
        featureGate.subscriptionState,
    ) { tasks, filter, sort, energy, subState ->
        TasksUiState(
            tasks = tasks,
            selectedFilter = filter,
            selectedSort = sort,
            energyFilter = energy,
            isLoading = false,
            isPro = subState.isPro,
        )
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), TasksUiState())

    fun selectFilter(filter: TaskFilter) {
        _selectedFilter.value = filter
    }

    fun selectSort(sort: TaskSortOption) {
        _selectedSort.value = sort
    }

    fun selectEnergyFilter(energy: EnergyLevel?) {
        _energyFilter.value = energy
    }

    fun toggleTaskCompletion(taskId: String) = viewModelScope.launch {
        taskRepository.toggleCompletion(taskId).onFailure {
            _errorEvent.emit("Failed to update task")
        }
    }

    fun addQuickTask(title: String) {
        if (title.isBlank()) return
        val activeCount = uiState.value.tasks.count { !it.isCompleted }
        if (!featureGate.canAddTask(activeCount)) {
            _showPaywall.value = true
            return
        }
        viewModelScope.launch {
            val currentFilter = _selectedFilter.value
            taskRepository.addTask(
                Task(
                    title = title.trim(),
                    scheduledForToday = currentFilter == TaskFilter.Today,
                    sortOrder = uiState.value.tasks.size,
                ),
            ).onSuccess {
                _successMessage.value = "Task added"
            }.onFailure {
                _errorEvent.emit("Failed to add task")
            }
        }
    }

    fun dismissPaywall() {
        _showPaywall.value = false
    }

    fun deleteTask(taskId: String) = viewModelScope.launch {
        taskRepository.deleteTaskWithUndo(taskId)
            .onSuccess { deletedTask ->
                if (deletedTask != null) {
                    undoExpiryJob?.cancel()
                    _undoEvent.value = UndoState(task = deletedTask)
                    undoExpiryJob = viewModelScope.launch {
                        delay(5000)
                        _undoEvent.value = null
                    }
                }
            }
            .onFailure {
                _errorEvent.emit("Failed to delete task")
            }
    }

    fun undoDelete() {
        val state = _undoEvent.value ?: return
        undoExpiryJob?.cancel()
        _undoEvent.value = null
        viewModelScope.launch {
            taskRepository.restoreTask(state.task).onFailure {
                _errorEvent.emit("Failed to restore task")
            }
        }
    }

    fun dismissUndo() {
        undoExpiryJob?.cancel()
        _undoEvent.value = null
    }

    fun reorderTasks(fromIndex: Int, toIndex: Int) {
        if (fromIndex == toIndex) return
        val currentTasks = uiState.value.filteredTasks.toMutableList()
        if (fromIndex !in currentTasks.indices || toIndex !in currentTasks.indices) return
        val movedTask = currentTasks.removeAt(fromIndex)
        currentTasks.add(toIndex, movedTask)
        val orderedIds = currentTasks.mapIndexed { index, task -> task.id to index }
        viewModelScope.launch {
            taskRepository.reorderTasks(orderedIds).onFailure {
                _errorEvent.emit("Failed to reorder tasks")
            }
        }
    }
}

data class UndoState(
    val task: Task,
)
