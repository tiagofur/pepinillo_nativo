package dev.creapolis.pepinillo.domain.timer

import dev.creapolis.pepinillo.data.local.preferences.UserPreferences
import dev.creapolis.pepinillo.data.local.preferences.UserPreferencesRepository
import dev.creapolis.pepinillo.data.repository.SessionRepository
import dev.creapolis.pepinillo.data.repository.TaskRepository
import dev.creapolis.pepinillo.feature.focus.FocusMode
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class FocusEngine @Inject constructor(
    private val sessionRepository: SessionRepository,
    private val taskRepository: TaskRepository,
    private val prefsRepo: UserPreferencesRepository,
) {
    private val _state = MutableStateFlow(FocusTimerState())
    val state: StateFlow<FocusTimerState> = _state.asStateFlow()

    private var timerJob: Job? = null
    private val scope: CoroutineScope = CoroutineScope(SupervisorJob() + Dispatchers.Main)

    fun selectMode(mode: FocusMode) {
        if (_state.value.status != TimerStatus.Idle) return
        scope.launch {
            val prefs = prefsRepo.preferences.first()
            _state.value = FocusTimerState(
                mode = mode,
                totalMillis = getTotalMillis(mode, prefs),
                linkedTaskId = _state.value.linkedTaskId,
            )
        }
    }

    fun start() {
        val current = _state.value
        if (current.status == TimerStatus.Running) return

        _state.update {
            it.copy(
                status = TimerStatus.Running,
                sessionStartTime = if (it.sessionStartTime == 0L) System.currentTimeMillis() else it.sessionStartTime,
            )
        }

        timerJob?.cancel()
        timerJob = scope.launch {
            val tickInterval = 100L
            while (true) {
                delay(tickInterval)
                val s = _state.value
                if (s.status != TimerStatus.Running) break

                val newElapsed = s.elapsedMillis + tickInterval
                _state.update { it.copy(elapsedMillis = newElapsed) }

                // Check completion for countdown modes
                if (s.mode != FocusMode.Flow && s.mode != FocusMode.Chrono) {
                    if (newElapsed >= s.totalMillis) {
                        onPhaseComplete()
                        break
                    }
                }
            }
        }
    }

    fun pause() {
        timerJob?.cancel()
        _state.update { it.copy(status = TimerStatus.Paused) }
    }

    fun stop() {
        timerJob?.cancel()
        val s = _state.value
        if (s.elapsedMillis > 0 && s.sessionStartTime > 0) {
            scope.launch {
                recordSession(s)
            }
        }
        scope.launch {
            val prefs = prefsRepo.preferences.first()
            _state.value = FocusTimerState(
                mode = s.mode,
                totalMillis = getTotalMillis(s.mode, prefs),
                linkedTaskId = s.linkedTaskId,
            )
        }
    }

    fun linkTask(taskId: String?) {
        _state.update { it.copy(linkedTaskId = taskId) }
    }

    private suspend fun onPhaseComplete() {
        val s = _state.value

        // Record the completed phase as a session
        recordSession(s)

        val prefs = prefsRepo.preferences.first()

        when {
            // Pomodoro mode: cycle through work → break → work → ... → long break
            s.mode == FocusMode.Pomodoro && s.phase == FocusPhase.Work -> {
                val newCompleted = s.completedSessions + 1
                val isLongBreak = newCompleted % prefs.sessionsBeforeLongBreak == 0
                val breakMillis = if (isLongBreak) {
                    prefs.longBreakMinutes * 60 * 1000L
                } else {
                    prefs.shortBreakMinutes * 60 * 1000L
                }
                _state.value = FocusTimerState(
                    mode = FocusMode.Pomodoro,
                    phase = if (isLongBreak) FocusPhase.LongBreak else FocusPhase.ShortBreak,
                    status = if (prefs.autoStartBreaks) TimerStatus.Running else TimerStatus.Idle,
                    totalMillis = breakMillis,
                    completedSessions = newCompleted,
                    linkedTaskId = s.linkedTaskId,
                    sessionStartTime = if (prefs.autoStartBreaks) System.currentTimeMillis() else 0L,
                )
                if (prefs.autoStartBreaks) start()
            }

            s.mode == FocusMode.Pomodoro && (s.phase == FocusPhase.ShortBreak || s.phase == FocusPhase.LongBreak) -> {
                _state.value = FocusTimerState(
                    mode = FocusMode.Pomodoro,
                    phase = FocusPhase.Work,
                    status = if (prefs.autoStartNextPomodoro) TimerStatus.Running else TimerStatus.Idle,
                    totalMillis = prefs.pomodoroMinutes * 60 * 1000L,
                    completedSessions = s.completedSessions,
                    linkedTaskId = s.linkedTaskId,
                    sessionStartTime = if (prefs.autoStartNextPomodoro) System.currentTimeMillis() else 0L,
                )
                if (prefs.autoStartNextPomodoro) start()
            }

            // Blocks mode: just stop when done
            s.mode == FocusMode.Blocks -> {
                _state.value = FocusTimerState(
                    mode = FocusMode.Blocks,
                    totalMillis = getTotalMillis(FocusMode.Blocks, prefs),
                    completedSessions = s.completedSessions + 1,
                    linkedTaskId = s.linkedTaskId,
                )
            }

            else -> {
                _state.value = FocusTimerState(
                    mode = s.mode,
                    totalMillis = getTotalMillis(s.mode, prefs),
                    linkedTaskId = s.linkedTaskId,
                )
            }
        }
    }

    private suspend fun recordSession(s: FocusTimerState) {
        if (s.elapsedMillis < 1000) return // ignore sessions shorter than 1 second

        val now = System.currentTimeMillis()
        sessionRepository.recordSession(
            mode = s.mode.name,
            startTime = s.sessionStartTime,
            endTime = now,
            durationMillis = s.elapsedMillis,
            linkedTaskId = s.linkedTaskId,
            phase = s.phase.name,
        )

        // Increment pomodoro count on linked task if this was a work phase
        if (s.linkedTaskId != null && s.phase == FocusPhase.Work) {
            taskRepository.incrementPomodoros(s.linkedTaskId)
        }
    }

    private fun getTotalMillis(mode: FocusMode, prefs: UserPreferences): Long = when (mode) {
        FocusMode.Pomodoro -> prefs.pomodoroMinutes * 60 * 1000L
        FocusMode.Blocks -> prefs.timeBlockMinutes * 60 * 1000L
        FocusMode.Flow, FocusMode.Chrono -> 0L
    }
}
