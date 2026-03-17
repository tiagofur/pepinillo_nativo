package dev.creapolis.pepinillo.feature.focus

import android.content.Context
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import dagger.hilt.android.lifecycle.HiltViewModel
import dagger.hilt.android.qualifiers.ApplicationContext
import dev.creapolis.pepinillo.data.repository.SessionRepository
import dev.creapolis.pepinillo.data.repository.TaskRepository
import dev.creapolis.pepinillo.domain.timer.FocusEngine
import dev.creapolis.pepinillo.domain.timer.TimerStatus
import dev.creapolis.pepinillo.domain.timer.displayTime
import dev.creapolis.pepinillo.domain.timer.phaseLabel
import dev.creapolis.pepinillo.domain.timer.progress
import dev.creapolis.pepinillo.feature.tasks.model.Task
import dev.creapolis.pepinillo.service.FocusTimerService
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale
import javax.inject.Inject

data class FocusUiState(
    val selectedMode: FocusMode = FocusMode.Pomodoro,
    val displayTime: String = "25:00",
    val progress: Float = 1f,
    val phaseLabel: String = "Focus",
    val isRunning: Boolean = false,
    val isPaused: Boolean = false,
    val linkedTaskName: String? = null,
    val sessionsToday: Int = 0,
    val currentStreak: Int = 0,
    val greeting: String = "",
    val currentDate: String = "",
    val showTaskPicker: Boolean = false,
)

@HiltViewModel
class FocusViewModel @Inject constructor(
    @ApplicationContext private val context: Context,
    private val focusEngine: FocusEngine,
    private val sessionRepository: SessionRepository,
    private val taskRepository: TaskRepository,
) : ViewModel() {

    private val _linkedTaskName = MutableStateFlow<String?>(null)
    private val _showTaskPicker = MutableStateFlow(false)
    val showTaskPicker: StateFlow<Boolean> = _showTaskPicker.asStateFlow()

    val activeTasks: StateFlow<List<Task>> = taskRepository.getActiveTasks()
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), emptyList())

    init {
        // Watch engine state to manage foreground service lifecycle
        viewModelScope.launch {
            focusEngine.state.collect { state ->
                when (state.status) {
                    TimerStatus.Running -> FocusTimerService.start(context)
                    TimerStatus.Idle -> FocusTimerService.stop(context)
                    TimerStatus.Paused -> { /* service stays alive while paused */ }
                }
            }
        }

        // Resolve linked task name when engine state changes
        viewModelScope.launch {
            focusEngine.state.collect { state ->
                val taskId = state.linkedTaskId
                _linkedTaskName.value = if (taskId != null) {
                    taskRepository.getTaskById(taskId)?.title
                } else {
                    null
                }
            }
        }
    }

    val uiState: StateFlow<FocusUiState> = combine(
        focusEngine.state,
        sessionRepository.getTodaySessionCount(),
        sessionRepository.getAllDaysWithSessions(),
        _linkedTaskName,
        _showTaskPicker,
    ) { timerState, todayCount, allDays, linkedTaskName, showPicker ->
        FocusUiState(
            selectedMode = timerState.mode,
            displayTime = timerState.displayTime,
            progress = timerState.progress,
            phaseLabel = timerState.phaseLabel,
            isRunning = timerState.status == TimerStatus.Running,
            isPaused = timerState.status == TimerStatus.Paused,
            linkedTaskName = linkedTaskName,
            sessionsToday = todayCount,
            currentStreak = sessionRepository.calculateCurrentStreak(allDays),
            greeting = computeGreeting(),
            currentDate = computeDate(),
            showTaskPicker = showPicker,
        )
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), FocusUiState(
        greeting = computeGreeting(),
        currentDate = computeDate(),
    ))

    fun selectMode(mode: FocusMode) {
        viewModelScope.launch { focusEngine.selectMode(mode) }
    }

    fun onStartStopClick() {
        val state = focusEngine.state.value
        when (state.status) {
            TimerStatus.Idle -> focusEngine.start()
            TimerStatus.Running -> focusEngine.pause()
            TimerStatus.Paused -> focusEngine.start()
        }
    }

    fun onStopClick() {
        focusEngine.stop()
    }

    fun onTaskLinkClick() {
        _showTaskPicker.value = true
    }

    fun dismissTaskPicker() {
        _showTaskPicker.value = false
    }

    fun linkTask(taskId: String?) {
        focusEngine.linkTask(taskId)
        _showTaskPicker.value = false
    }

    private fun computeGreeting(): String {
        val hour = Calendar.getInstance().get(Calendar.HOUR_OF_DAY)
        return when {
            hour < 12 -> "Good morning"
            hour < 18 -> "Good afternoon"
            else -> "Good evening"
        }
    }

    private fun computeDate(): String {
        val dateFormat = SimpleDateFormat("EEEE, MMMM d", Locale.getDefault())
        return dateFormat.format(Date())
    }
}
