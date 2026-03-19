package dev.creapolis.pepinillo.domain.timer

import android.os.SystemClock
import dev.creapolis.pepinillo.data.local.preferences.UserPreferences
import dev.creapolis.pepinillo.data.local.preferences.UserPreferencesRepository
import dev.creapolis.pepinillo.data.repository.SessionRepository
import dev.creapolis.pepinillo.data.repository.TaskRepository
import dev.creapolis.pepinillo.di.ApplicationScope
import dev.creapolis.pepinillo.feature.focus.FocusMode
import dev.creapolis.pepinillo.platform.feedback.FeedbackManager
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
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
    private val feedbackManager: FeedbackManager,
    @ApplicationScope private val scope: CoroutineScope,
) {
    private val _state = MutableStateFlow(FocusTimerState())
    val state: StateFlow<FocusTimerState> = _state.asStateFlow()

    private var timerJob: Job? = null

    // Cached preferences for use in the tick loop (avoids reading DataStore every 100ms)
    private var cachedPrefs: UserPreferences = UserPreferences()

    suspend fun selectMode(mode: FocusMode) {
        if (_state.value.status != TimerStatus.Idle) return
        val prefs = prefsRepo.preferences.first()
        _state.value = FocusTimerState(
            mode = mode,
            totalMillis = getTotalMillis(mode, prefs),
            linkedTaskId = _state.value.linkedTaskId,
        )
    }

    /** Restores timer state after process death (START_STICKY service restart). */
    suspend fun restoreState(
        mode: FocusMode,
        phase: FocusPhase,
        elapsedMillis: Long,
        totalMillis: Long,
        completedSessions: Int,
        sessionStartTime: Long,
        status: TimerStatus = TimerStatus.Running,
    ) {
        val prefs = prefsRepo.preferences.first()
        cachedPrefs = prefs
        val resolvedTotal = if (totalMillis > 0L) totalMillis else getTotalMillis(mode, prefs)

        // Restore WaitingForNext without starting timer loop
        if (status == TimerStatus.WaitingForNext) {
            _state.value = FocusTimerState(
                mode = mode,
                phase = phase,
                status = TimerStatus.WaitingForNext,
                totalMillis = resolvedTotal,
                completedSessions = completedSessions,
            )
            return
        }

        // If the phase already completed while the process was dead, handle it
        if (mode != FocusMode.Flow && mode != FocusMode.Chrono && elapsedMillis >= resolvedTotal) {
            _state.value = FocusTimerState(
                mode = mode,
                phase = phase,
                status = TimerStatus.Running,
                elapsedMillis = resolvedTotal,
                totalMillis = resolvedTotal,
                completedSessions = completedSessions,
                sessionStartTime = sessionStartTime,
            )
            onPhaseComplete()
        } else {
            _state.value = FocusTimerState(
                mode = mode,
                phase = phase,
                status = TimerStatus.Running,
                elapsedMillis = elapsedMillis,
                totalMillis = resolvedTotal,
                completedSessions = completedSessions,
                sessionStartTime = sessionStartTime,
            )
            startTimerLoop()
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

        startTimerLoop()
    }

    /**
     * Creates a new timer tick loop. Called by start() for user actions, and directly
     * by onPhaseComplete()/restoreState() to bypass the Running guard in start().
     *
     * @param cancelPrevious When false, skips cancelling the current timerJob. Used when
     *   called from within onPhaseComplete() (which runs inside the current timerJob)
     *   to avoid self-cancellation. The old coroutine exits naturally via break.
     */
    private fun startTimerLoop(cancelPrevious: Boolean = true) {
        if (cancelPrevious) timerJob?.cancel()
        timerJob = scope.launch {
            // Cache prefs at session start
            cachedPrefs = prefsRepo.preferences.first()

            val tickInterval = 100L
            // Use wall-clock anchoring to avoid drift from delay() imprecision
            val loopStartRealtime = SystemClock.elapsedRealtime()
            val initialElapsed = _state.value.elapsedMillis

            while (true) {
                delay(tickInterval)
                val s = _state.value
                if (s.status != TimerStatus.Running) break

                val newElapsed = initialElapsed + (SystemClock.elapsedRealtime() - loopStartRealtime)
                _state.update { it.copy(elapsedMillis = newElapsed) }

                // Flowtime: suggest break after minimum session time
                if (s.mode == FocusMode.Flow && !s.breakSuggested) {
                    val minMillis = cachedPrefs.flowtimeMinMinutes * 60 * 1000L
                    if (newElapsed >= minMillis) {
                        _state.update { it.copy(breakSuggested = true) }
                        feedbackManager.onPhaseComplete()
                    }
                }

                // Blocks: midpoint check-in
                if (s.mode == FocusMode.Blocks && cachedPrefs.midpointCheckIn && !s.midpointTriggered) {
                    if (s.totalMillis > 0 && newElapsed >= s.totalMillis / 2) {
                        _state.update { it.copy(midpointTriggered = true) }
                        feedbackManager.onPhaseComplete()
                    }
                }

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
        val snapshot = _state.value
        scope.launch {
            if (snapshot.elapsedMillis > 0 && snapshot.sessionStartTime > 0) {
                recordSession(snapshot)
            }
            val prefs = prefsRepo.preferences.first()
            _state.value = FocusTimerState(
                mode = snapshot.mode,
                totalMillis = getTotalMillis(snapshot.mode, prefs),
                linkedTaskId = snapshot.linkedTaskId,
            )
        }
    }

    fun linkTask(taskId: String?) {
        _state.update { it.copy(linkedTaskId = taskId) }
    }

    private suspend fun onPhaseComplete() {
        val s = _state.value

        // Sound/haptic feedback on phase completion
        feedbackManager.onPhaseComplete()

        // Record the completed phase as a session
        recordSession(s)

        val prefs = prefsRepo.preferences.first()

        when {
            // Pomodoro mode: cycle through work → break → work → ... → long break
            s.mode == FocusMode.Pomodoro && s.phase == FocusPhase.Work -> {
                val newCompleted = s.completedSessions + 1
                val isLongBreak = prefs.sessionsBeforeLongBreak > 0 &&
                    newCompleted % prefs.sessionsBeforeLongBreak == 0
                val breakMillis = if (isLongBreak) {
                    prefs.longBreakMinutes * 60 * 1000L
                } else {
                    prefs.shortBreakMinutes * 60 * 1000L
                }
                _state.value = FocusTimerState(
                    mode = FocusMode.Pomodoro,
                    phase = if (isLongBreak) FocusPhase.LongBreak else FocusPhase.ShortBreak,
                    status = if (prefs.autoStartBreaks) TimerStatus.Running else TimerStatus.WaitingForNext,
                    totalMillis = breakMillis,
                    completedSessions = newCompleted,
                    linkedTaskId = s.linkedTaskId,
                    sessionStartTime = if (prefs.autoStartBreaks) System.currentTimeMillis() else 0L,
                )
                if (prefs.autoStartBreaks) startTimerLoop(cancelPrevious = false)
            }

            s.mode == FocusMode.Pomodoro && (s.phase == FocusPhase.ShortBreak || s.phase == FocusPhase.LongBreak) -> {
                _state.value = FocusTimerState(
                    mode = FocusMode.Pomodoro,
                    phase = FocusPhase.Work,
                    status = if (prefs.autoStartNextPomodoro) TimerStatus.Running else TimerStatus.WaitingForNext,
                    totalMillis = prefs.pomodoroMinutes * 60 * 1000L,
                    completedSessions = s.completedSessions,
                    linkedTaskId = s.linkedTaskId,
                    sessionStartTime = if (prefs.autoStartNextPomodoro) System.currentTimeMillis() else 0L,
                )
                if (prefs.autoStartNextPomodoro) startTimerLoop(cancelPrevious = false)
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
