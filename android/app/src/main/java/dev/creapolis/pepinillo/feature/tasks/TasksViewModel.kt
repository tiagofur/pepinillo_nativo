package dev.creapolis.pepinillo.feature.tasks

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import dagger.hilt.android.lifecycle.HiltViewModel
import dev.creapolis.pepinillo.data.repository.TaskRepository
import dev.creapolis.pepinillo.feature.tasks.model.EnergyLevel
import dev.creapolis.pepinillo.feature.tasks.model.Task
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import javax.inject.Inject

enum class TaskFilter(val label: String) {
    All("All"),
    Active("Active"),
    Completed("Done"),
}

data class TasksUiState(
    val tasks: List<Task> = emptyList(),
    val selectedFilter: TaskFilter = TaskFilter.All,
    val showAddDialog: Boolean = false,
)

val TasksUiState.filteredTasks: List<Task>
    get() = when (selectedFilter) {
        TaskFilter.All -> tasks
        TaskFilter.Active -> tasks.filter { !it.isCompleted }
        TaskFilter.Completed -> tasks.filter { it.isCompleted }
    }

val TasksUiState.activeCount: Int
    get() = tasks.count { !it.isCompleted }

@HiltViewModel
class TasksViewModel @Inject constructor(
    private val taskRepository: TaskRepository,
) : ViewModel() {

    private val _selectedFilter = MutableStateFlow(TaskFilter.All)
    private val _showAddDialog = MutableStateFlow(false)

    val uiState: StateFlow<TasksUiState> = combine(
        taskRepository.getAllTasks(),
        _selectedFilter,
        _showAddDialog,
    ) { tasks, filter, showDialog ->
        TasksUiState(
            tasks = tasks,
            selectedFilter = filter,
            showAddDialog = showDialog,
        )
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), TasksUiState())

    fun selectFilter(filter: TaskFilter) {
        _selectedFilter.value = filter
    }

    fun toggleTaskCompletion(taskId: String) = viewModelScope.launch {
        taskRepository.toggleCompletion(taskId)
    }

    fun showAddDialog() {
        _showAddDialog.value = true
    }

    fun dismissAddDialog() {
        _showAddDialog.value = false
    }

    fun addTask(title: String, energyLevel: EnergyLevel, estimatedPomodoros: Int) {
        if (title.isBlank()) return
        viewModelScope.launch {
            taskRepository.addTask(
                Task(
                    title = title,
                    energyLevel = energyLevel,
                    estimatedPomodoros = estimatedPomodoros,
                ),
            )
            _showAddDialog.value = false
        }
    }

    fun deleteTask(taskId: String) = viewModelScope.launch {
        taskRepository.deleteTask(taskId)
    }
}
