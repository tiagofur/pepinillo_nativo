package dev.creapolis.pepinillo.feature.focus

import android.content.Context
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import dagger.hilt.android.lifecycle.HiltViewModel
import dagger.hilt.android.qualifiers.ApplicationContext
import dev.creapolis.pepinillo.data.repository.SessionRepository
import dev.creapolis.pepinillo.domain.timer.FocusEngine
import dev.creapolis.pepinillo.domain.timer.TimerStatus
import dev.creapolis.pepinillo.domain.timer.displayTime
import dev.creapolis.pepinillo.domain.timer.phaseLabel
import dev.creapolis.pepinillo.domain.timer.progress
import dev.creapolis.pepinillo.service.FocusTimerService
import dev.creapolis.pepinillo.widget.FocusTimerWidget
import dev.creapolis.pepinillo.widget.TimerWidgetState
import dev.creapolis.pepinillo.widget.updateWidgetState
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
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
)

@HiltViewModel
class FocusViewModel @Inject constructor(
    @ApplicationContext private val context: Context,
    private val focusEngine: FocusEngine,
    private val sessionRepository: SessionRepository,
) : ViewModel() {

    init {
        // Watch engine state to manage foreground service lifecycle
        viewModelScope.launch {
            focusEngine.state.collect { state ->
                when (state.status) {
                    TimerStatus.Running -> FocusTimerService.start(context)
                    TimerStatus.Idle -> FocusTimerService.stop(context)
                    TimerStatus.Paused -> { /* service stays alive while paused */ }
                }
                
                // Update widget when state changes
                val widgetState = TimerWidgetState(
                    mode = state.mode,
                    selectedMode = state.mode,
                    displayTime = state.displayTime,
                    phaseLabel = state.phaseLabel,
                    status = state.status,
                    progress = state.progress,
                )
                updateWidgetState(context, widgetState)
                FocusTimerWidget().updateAll(context)
            }
        }
    }

    val uiState: StateFlow<FocusUiState> = combine(
        focusEngine.state,
        sessionRepository.getTodaySessionCount(),
    ) { timerState, todayCount ->
        FocusUiState(
            selectedMode = timerState.mode,
            displayTime = timerState.displayTime,
            progress = timerState.progress,
            phaseLabel = timerState.phaseLabel,
            isRunning = timerState.status == TimerStatus.Running,
            isPaused = timerState.status == TimerStatus.Paused,
            linkedTaskName = null,
            sessionsToday = todayCount,
            currentStreak = 0,
            greeting = computeGreeting(),
            currentDate = computeDate(),
        )
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), FocusUiState(
        greeting = computeGreeting(),
        currentDate = computeDate(),
    ))

    fun selectMode(mode: FocusMode) {
        focusEngine.selectMode(mode)
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
