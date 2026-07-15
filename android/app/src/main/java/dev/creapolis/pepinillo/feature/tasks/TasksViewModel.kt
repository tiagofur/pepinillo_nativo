package dev.creapolis.pepinillo.feature.tasks

import android.content.Context
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import dagger.hilt.android.lifecycle.HiltViewModel
import dagger.hilt.android.qualifiers.ApplicationContext
import dev.creapolis.pepinillo.R
import dev.creapolis.pepinillo.core.billing.FeatureGate
import dev.creapolis.pepinillo.data.repository.TaskRepository
import dev.creapolis.pepinillo.domain.timer.FocusEngine
import dev.creapolis.pepinillo.feature.tasks.model.EnergyLevel
import dev.creapolis.pepinillo.feature.tasks.model.Task
import dev.creapolis.pepinillo.feature.tasks.model.TaskPriority
import dev.creapolis.pepinillo.widget.WidgetTaskStateManager
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
import java.util.Calendar
import java.util.TimeZone
import javax.inject.Inject

enum class TaskFilter {
    Today,
    Inbox,
    Upcoming,
    Completed,
}

enum class TaskSortOption {
    Custom,
    Priority,
    DueDate,
    Energy,
    Newest,
}

data class TasksUiState(
    val tasks: List<Task> = emptyList(),
    val selectedFilter: TaskFilter = TaskFilter.Today,
    val selectedSort: TaskSortOption = TaskSortOption.Custom,
    val energyFilter: EnergyLevel? = null,
    val isLoading: Boolean = true,
    val isPro: Boolean = false,
    /** Pre-computed filtered+sorted list. Memoized in the VM combine so it recalculates
     *  only when tasks/filter/sort/energy change — not on every recomposition. */
    val filteredTasks: List<Task> = emptyList(),
)

private fun TasksUiState.computeFilteredTasks(): List<Task> {
        // Compute "today" once per evaluation instead of allocating 3 Calendars per task.
        val todayNorm = getNormalizedLocalDate()
        // 1. Plan category filter
        val statusFiltered = when (selectedFilter) {
            // Today: explicitly scheduled today OR due today OR overdue
            TaskFilter.Today -> tasks.filter { task ->
                !task.isCompleted && (
                    task.scheduledForToday ||
                    (task.dueDate != null && (isDueTodayMs(task.dueDate, todayNorm) || isBeforeTodayMs(task.dueDate, todayNorm)))
                )
            }
            // Inbox: no due date, not scheduled today
            TaskFilter.Inbox -> tasks.filter { task ->
                !task.isCompleted && !task.scheduledForToday && task.dueDate == null
            }
            // Upcoming: all future dues (strictly after today). Issue #182.
            TaskFilter.Upcoming -> tasks.filter { task ->
                !task.isCompleted &&
                    !task.scheduledForToday &&
                    task.dueDate != null &&
                    isUpcomingMs(task.dueDate, todayNorm)
            }
            TaskFilter.Completed -> tasks.filter { it.isCompleted }
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

private fun getNormalizedLocalDate(): Calendar {
    val local = Calendar.getInstance()
    return Calendar.getInstance(TimeZone.getTimeZone("UTC")).apply {
        clear()
        set(Calendar.YEAR, local.get(Calendar.YEAR))
        set(Calendar.MONTH, local.get(Calendar.MONTH))
        set(Calendar.DAY_OF_MONTH, local.get(Calendar.DAY_OF_MONTH))
    }
}

private fun getNormalizedDueDate(millis: Long): Calendar {
    val due = Calendar.getInstance(TimeZone.getTimeZone("UTC")).apply { timeInMillis = millis }
    return Calendar.getInstance(TimeZone.getTimeZone("UTC")).apply {
        clear()
        set(Calendar.YEAR, due.get(Calendar.YEAR))
        set(Calendar.MONTH, due.get(Calendar.MONTH))
        set(Calendar.DAY_OF_MONTH, due.get(Calendar.DAY_OF_MONTH))
    }
}

private fun isDueTodayMs(millis: Long, todayNorm: Calendar): Boolean {
    val dueNorm = getNormalizedDueDate(millis)
    return dueNorm == todayNorm
}

private fun isBeforeTodayMs(millis: Long, todayNorm: Calendar): Boolean {
    val dueNorm = getNormalizedDueDate(millis)
    return dueNorm.before(todayNorm)
}

internal fun isUpcomingMs(millis: Long, todayNorm: Calendar): Boolean {
    val dueNorm = getNormalizedDueDate(millis)
    return dueNorm.after(todayNorm)
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
    private val focusEngine: FocusEngine,
    @param:ApplicationContext private val context: Context,
) : ViewModel() {

    private val _selectedFilter = MutableStateFlow(TaskFilter.Today)
    private val _selectedSort = MutableStateFlow(TaskSortOption.Newest)
    private val _energyFilter = MutableStateFlow<EnergyLevel?>(null)
    private val _showPaywall = MutableStateFlow(false)
    val showPaywall: StateFlow<Boolean> = _showPaywall.asStateFlow()

    private val _errorEvent = MutableSharedFlow<Int>()
    val errorEvent: SharedFlow<Int> = _errorEvent.asSharedFlow()

    private val _undoEvent = MutableStateFlow<UndoState?>(null)
    val undoEvent: StateFlow<UndoState?> = _undoEvent.asStateFlow()
    private var undoExpiryJob: Job? = null

    private val _successMessage = MutableStateFlow<Int?>(null)
    val successMessage: StateFlow<Int?> = _successMessage.asStateFlow()
    fun dismissSuccessMessage() { _successMessage.value = null }

    val uiState: StateFlow<TasksUiState> = combine(
        taskRepository.getAllTasks(),
        _selectedFilter,
        _selectedSort,
        _energyFilter,
        featureGate.subscriptionState,
    ) { tasks, filter, sort, energy, subState ->
        val base = TasksUiState(
            tasks = tasks,
            selectedFilter = filter,
            selectedSort = sort,
            energyFilter = energy,
            isLoading = false,
            isPro = subState.hasLocalPremium,
        )
        base.copy(filteredTasks = base.computeFilteredTasks())
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
            _errorEvent.emit(R.string.msg_task_update_failed)
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
                _successMessage.value = R.string.msg_task_added
            }.onFailure {
                _errorEvent.emit(R.string.msg_task_add_failed)
            }
        }
    }

    fun dismissPaywall() {
        _showPaywall.value = false
    }

    fun startFocusOnTask(taskId: String) {
        focusEngine.linkTask(taskId)
        focusEngine.start()
        _successMessage.value = R.string.msg_task_linked

        viewModelScope.launch {
            WidgetTaskStateManager.updateLinkedTaskId(context, taskId)
        }
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
                _errorEvent.emit(R.string.msg_task_delete_failed)
            }
    }

    fun undoDelete() {
        val state = _undoEvent.value ?: return
        undoExpiryJob?.cancel()
        _undoEvent.value = null
        viewModelScope.launch {
            taskRepository.restoreTask(state.task).onFailure {
                _errorEvent.emit(R.string.msg_task_restore_failed)
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
                _errorEvent.emit(R.string.msg_task_reorder_failed)
            }
        }
    }
}

data class UndoState(
    val task: Task,
)
