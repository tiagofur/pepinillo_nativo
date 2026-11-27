package dev.creapolis.pepinillo.feature.tasks

import android.content.Context
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.UUID
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import dagger.hilt.android.lifecycle.HiltViewModel
import dagger.hilt.android.qualifiers.ApplicationContext
import dev.creapolis.pepinillo.R
import dev.creapolis.pepinillo.core.billing.FeatureGate
import dev.creapolis.pepinillo.data.repository.TaskRepository
import dev.creapolis.pepinillo.domain.tasks.TaskPlanning
import dev.creapolis.pepinillo.domain.tasks.DueDateEncoding
import dev.creapolis.pepinillo.domain.tasks.NaturalDateParser
import dev.creapolis.pepinillo.domain.timer.FocusEngine
import dev.creapolis.pepinillo.feature.tasks.model.EnergyLevel
import dev.creapolis.pepinillo.feature.tasks.model.MAX_TASK_TITLE_LENGTH
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
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import java.util.Calendar
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
    val subtaskProgressMap: Map<String, Pair<Int, Int>> = emptyMap(),
    val selectedFilter: TaskFilter = TaskFilter.Today,
    val selectedSort: TaskSortOption = TaskSortOption.Custom,
    val energyFilter: EnergyLevel? = null,
    val isLoading: Boolean = true,
    val isPro: Boolean = false,
    /** Pre-computed filtered+sorted list. Memoized in the VM combine so it recalculates
     *  only when tasks/filter/sort/energy change — not on every recomposition. */
    val filteredTasks: List<Task> = emptyList(),
)

internal fun TasksUiState.computeFilteredTasks(): List<Task> {
        // 1. Plan category filter — unified «Hoy» rule (issue #991 S2), one
        // resolver for the whole app (domain/tasks/TaskPlanning.kt).
        val statusFiltered = when (selectedFilter) {
            TaskFilter.Today -> tasks.filter {
                TaskPlanning.bucket(
                    plannedDate = it.plannedDate,
                    dueDate = it.dueDate,
                    scheduledForToday = it.scheduledForToday,
                    isCompleted = it.isCompleted,
                ) is TaskPlanning.Bucket.Today
            }
            TaskFilter.Inbox -> tasks.filter {
                TaskPlanning.bucket(
                    plannedDate = it.plannedDate,
                    dueDate = it.dueDate,
                    scheduledForToday = it.scheduledForToday,
                    isCompleted = it.isCompleted,
                ) is TaskPlanning.Bucket.Inbox
            }
            // #182: no one-week cap — Upcoming holds every future date.
            TaskFilter.Upcoming -> tasks.filter {
                TaskPlanning.bucket(
                    plannedDate = it.plannedDate,
                    dueDate = it.dueDate,
                    scheduledForToday = it.scheduledForToday,
                    isCompleted = it.isCompleted,
                ) is TaskPlanning.Bucket.Upcoming
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

private fun getNormalizedLocalDate(): Calendar =
    // Shared single source of truth (C1): due dates are stored as local-midnight millis,
    // so day comparisons must normalize in the local timezone — identical to
    // [DueDateEncoding], which TaskItem badge decoding also uses.
    DueDateEncoding.normalizedLocalDate(System.currentTimeMillis())

private fun getNormalizedDueDate(millis: Long): Calendar =
    // Must use the SAME timezone as getNormalizedLocalDate for comparisons to be valid.
    DueDateEncoding.normalizedLocalDate(millis)

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
    @ApplicationContext private val context: Context,
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

    /// Quick-add that recognized a natural-language date (#994 S4): the
    /// snackbar offers «Quitar fecha», which clears the plan and restores
    /// the recognized text into the title.
    private val _parsedDateUndoEvent = MutableStateFlow<ParsedDateUndoState?>(null)
    val parsedDateUndoEvent: StateFlow<ParsedDateUndoState?> = _parsedDateUndoEvent.asStateFlow()
    private var undoExpiryJob: Job? = null
    private var parsedDateUndoExpiryJob: Job? = null

    private val _successMessage = MutableStateFlow<Int?>(null)
    val successMessage: StateFlow<Int?> = _successMessage.asStateFlow()
    fun dismissSuccessMessage() { _successMessage.value = null }

    private val tasksWithSubtasks = combine(
        taskRepository.getAllTasks(),
        taskRepository.getSubtaskProgressMap(),
    ) { tasks, subtaskProgressMap ->
        tasks to subtaskProgressMap
    }

    private val minuteTicker = kotlinx.coroutines.flow.flow {
        while (true) {
            emit(System.currentTimeMillis() / 60_000)
            kotlinx.coroutines.delay(60_000)
        }
    }

    private val filterWithTicker = combine(_selectedFilter, minuteTicker) { filter, _ -> filter }

    val uiState: StateFlow<TasksUiState> = combine(
        tasksWithSubtasks,
        filterWithTicker,
        _selectedSort,
        _energyFilter,
        featureGate.subscriptionState,
    ) { (tasks, subtaskProgressMap), filter, sort, energy, subState ->
        val base = TasksUiState(
            tasks = tasks,
            subtaskProgressMap = subtaskProgressMap,
            selectedFilter = filter,
            selectedSort = sort,
            energyFilter = energy,
            isLoading = false,
            isPro = subState.hasLocalPremium,
        )
        base.copy(filteredTasks = base.computeFilteredTasks())
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), TasksUiState())

    fun selectFilter(filter: TaskFilter) {
        // Issue #990 round 1 (judge A P1-2): the energy filter is Today-scoped —
        // switching tabs must clear it (computeFilteredTasks applies it to
        // every filter; the chip only renders on Today).
        _energyFilter.value = null
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
        viewModelScope.launch {
            // Read the authoritative active count inside the coroutine: the uiState
            // snapshot can be stale while a previous insert is still in flight
            // (quick-add limit race).
            val activeCount = taskRepository.getActiveCount().first()
            if (!featureGate.canAddTask(activeCount)) {
                _showPaywall.value = true
                return@launch
            }
            val currentFilter = _selectedFilter.value
            // #994: a natural-language date typed at the END of the text
            // replaces/refreshes the pill default; the recognized span leaves
            // the title and «Quitar fecha» can put it back (S4/S5).
            val trimmedTitle = title.trim()
            val parsed = NaturalDateParser.parse(trimmedTitle, System.currentTimeMillis())
            val effectiveTitle = parsed.title.ifBlank { trimmedTitle }
            // S5 (#991): quick add inherits a planned date — today from «Hoy»,
            // tomorrow from «Próximas». No deadline is invented anymore.
            val plannedDate = parsed.plannedDate ?: when (currentFilter) {
                TaskFilter.Today -> TaskPlanning.plannedDay()
                TaskFilter.Upcoming -> TaskPlanning.plannedDay(
                    Calendar.getInstance().apply { add(Calendar.DAY_OF_YEAR, 1) }.timeInMillis
                )
                else -> null
            }
            val newSortOrder =
                (taskRepository.getAllTasks().first().maxOfOrNull { it.sortOrder } ?: -1) + 1
            // The caller assigns the id so the undo binds to THIS row without
            // a post-insert lookup that a concurrent insert could hijack
            // (judge A/B P2, #994 PR-d).
            val newTaskId = UUID.randomUUID().toString()
            // The legacy flag follows the EFFECTIVE date (iOS/web parity):
            // a parsed future date lands in «Próximas», never in «Hoy» just
            // because the pill said so (judge A/B P2, #994 PR-d).
            val scheduledForToday = parsed.plannedDate?.let { planned ->
                !DueDateEncoding.normalizedLocalDate(planned)
                    .after(DueDateEncoding.normalizedLocalDate(System.currentTimeMillis()))
            } ?: (currentFilter == TaskFilter.Today)

            taskRepository.addTask(
                Task(
                    id = newTaskId,
                    title = effectiveTitle.take(MAX_TASK_TITLE_LENGTH),
                    scheduledForToday = scheduledForToday,
                    plannedDate = plannedDate,
                    dueDate = null,
                    // max+1 over the repository snapshot: tasks.size collides with an
                    // existing sort order when the list contains non-contiguous orders.
                    sortOrder = newSortOrder,
                ),
            ).onSuccess {
                if (parsed.plannedDate != null) {
                    // The undo snackbar replaces the plain «añadida» toast for
                    // this add — one transient surface, not two.
                    parsedDateUndoExpiryJob?.cancel()
                    _parsedDateUndoEvent.value = ParsedDateUndoState(
                        taskId = newTaskId,
                        title = trimmedTitle,
                        dateText = SimpleDateFormat("EEE d", Locale.getDefault())
                            .format(Date(parsed.plannedDate)),
                    )
                    parsedDateUndoExpiryJob = launch {
                        delay(UNDO_SNACKBAR_DURATION_MS)
                        _parsedDateUndoEvent.value = null
                    }
                } else if (currentFilter == TaskFilter.Completed) {
                    _successMessage.value = R.string.msg_task_added_to_inbox
                } else {
                    _successMessage.value = R.string.msg_task_added
                }
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
                        delay(UNDO_SNACKBAR_DURATION_MS)
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

    /// «Quitar fecha» for the last quick-add that recognized a natural
    /// language date (#994 S4): clears the plan and puts the recognized
    /// text back into the title.
    fun undoParsedDate() {
        val state = _parsedDateUndoEvent.value ?: return
        parsedDateUndoExpiryJob?.cancel()
        _parsedDateUndoEvent.value = null
        viewModelScope.launch {
            val task = taskRepository.getAllTasks().first()
                .firstOrNull { it.id == state.taskId } ?: return@launch
            taskRepository.updateTask(
                task.copy(
                    title = state.title.take(MAX_TASK_TITLE_LENGTH),
                    plannedDate = null,
                    scheduledForToday = false,
                )
            ).onFailure {
                _errorEvent.emit(R.string.msg_task_update_failed)
            }
        }
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

    companion object {
        /**
         * Undo snackbar window — single source of truth shared with the UI. Must match the
         * snackbar duration (Material 3 SnackbarDuration.Long ≈ 10s) so the Undo action never
         * disappears before the underlying event expires.
         */
        const val UNDO_SNACKBAR_DURATION_MS = 10_000L
    }
}

data class UndoState(
    val task: Task,
)

/// Quick-add whose natural-language date can be undone (#994 S4).
data class ParsedDateUndoState(
    val taskId: String,
    /// The exact text the parser removed — restored on «Quitar fecha».
    val title: String,
    /// Pre-formatted planned day for the snackbar message.
    val dateText: String,
)