package dev.creapolis.pepinillo.feature.tasks

import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import dagger.hilt.android.lifecycle.HiltViewModel
import dev.creapolis.pepinillo.data.repository.SessionRepository
import dev.creapolis.pepinillo.data.repository.TaskAnalytics
import dev.creapolis.pepinillo.data.repository.TaskRepository
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.flatMapLatest
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import javax.inject.Inject

data class TaskAnalyticsUiState(
    val taskTitle: String = "",
    val analytics: TaskAnalytics? = null,
    val isLoading: Boolean = true,
)

@HiltViewModel
@OptIn(ExperimentalCoroutinesApi::class)
class TaskAnalyticsViewModel @Inject constructor(
    savedStateHandle: SavedStateHandle,
    private val sessionRepository: SessionRepository,
    private val taskRepository: TaskRepository,
) : ViewModel() {

    private val taskId: String = checkNotNull(savedStateHandle["taskId"])

    private val _taskInfo = MutableStateFlow<Triple<String, Int, Int>?>(null)

    val uiState: StateFlow<TaskAnalyticsUiState> = _taskInfo.flatMapLatest { info ->
        if (info == null) {
            flowOf(TaskAnalyticsUiState(isLoading = true))
        } else {
            val (title, estimated, completed) = info
            sessionRepository.getTaskAnalytics(
                taskId = taskId,
                taskTitle = title,
                estimatedPomodoros = estimated,
                completedPomodoros = completed,
            ).map { analytics ->
                TaskAnalyticsUiState(
                    taskTitle = title,
                    analytics = analytics,
                    isLoading = false,
                )
            }
        }
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), TaskAnalyticsUiState())

    init {
        viewModelScope.launch {
            taskRepository.getTaskByIdFlow(taskId).collect { task ->
                if (task != null) {
                    _taskInfo.value = Triple(task.title, task.estimatedPomodoros, task.completedPomodoros)
                }
            }
        }
    }
}
