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
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.collect
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

    /** Emits the session ID whenever a work session completes (not breaks). */
    private val _workSessionCompleted = MutableSharedFlow<String>(extraBufferCapacity = 1)
    val workSessionCompleted: SharedFlow<String> = _workSessionCompleted.asSharedFlow()

    private var timerJob: Job? = null
    private var prefsObserverJob: Job? = null

    // Cached preferences for use in the tick loop (avoids reading DataStore every 250ms)
    private var cachedPrefs: UserPreferences = UserPreferences()

    init {
        // Observe preference changes while idle so the displayed time
        // reflects the latest settings without waiting for play to be pressed.
        startIdlePrefsObserver()
    }

    /**
     * Keeps totalMillis in sync with user preferences while the timer is idle.
     * This runs for the entire lifetime of the singleton and only acts when
     * the timer is NOT running/paused (the active-session observer handles those states).
     */
    private fun startIdlePrefsObserver() {
        scope.launch {
            var lastPrefs: UserPreferences? = null
            prefsRepo.preferences.collect { newPrefs ->
                val oldPrefs = lastPrefs
                lastPrefs = newPrefs
                if (oldPrefs == null) return@collect

                val s = _state.value
                if (s.status != TimerStatus.Idle && s.status != TimerStatus.WaitingForNext) return@collect

                val oldTotalMillis = getTotalMillis(s.mode, s.phase, oldPrefs)
                val newTotalMillis = getTotalMillis(s.mode, s.phase, newPrefs)
                if (oldTotalMillis != newTotalMillis) {
                    _state.update { it.copy(totalMillis = newTotalMillis) }
                }
            }
        }
    }

    // Pause / interruption tracking (internal, not exposed in FocusTimerState)
    private var pauseCount: Int = 0
    private var pauseStartTime: Long = 0L
    private var totalPauseMillis: Long = 0L
    private var interruptionCount: Int = 0
    private var pomodoroNumber: Int = 1

    init {
        // Observe preference changes and update the active timer's totalMillis in real-time.
        // This ensures that when the user changes Pomodoro/Block duration in Settings while
        // a timer is running or paused, the displayed remaining time updates immediately.
        scope.launch {
            prefsRepo.preferences.collect { prefs ->
                cachedPrefs = prefs
                val s = _state.value
                if (s.status != TimerStatus.Running && s.status != TimerStatus.Paused) return@collect
                val newTotalMillis = when {
                    s.mode == FocusMode.Pomodoro && s.phase == FocusPhase.Work ->
                        prefs.pomodoroMinutes * 60 * 1000L
                    s.mode == FocusMode.Pomodoro && s.phase == FocusPhase.ShortBreak ->
                        prefs.shortBreakMinutes * 60 * 1000L
                    s.mode == FocusMode.Pomodoro && s.phase == FocusPhase.LongBreak ->
                        prefs.longBreakMinutes * 60 * 1000L
                    s.mode == FocusMode.Blocks ->
                        prefs.timeBlockMinutes * 60 * 1000L
                    else -> return@collect
                }
                if (newTotalMillis != s.totalMillis) {
                    _state.update { it.copy(totalMillis = newTotalMillis) }
                }
            }
        }
    }

    // Day-change tracking for mid-session midnight crossing
    @Volatile private var currentDayStartMillis: Long = SessionRepository.startOfDay(System.currentTimeMillis())
    @Volatile private var nextDayStartMillis: Long = currentDayStartMillis + 86_400_000L

    /**
     * Resets daily counters when the calendar day changes.
     * Safe to call from the main thread (BroadcastReceiver) or from the timer coroutine.
     * Does NOT interrupt an in-progress session — the current session completes normally
     * and is counted as #1 of the new day.
     */
    fun onDayChanged() {
        val newDayStart = SessionRepository.startOfDay(System.currentTimeMillis())
        if (newDayStart == currentDayStartMillis) return
        currentDayStartMillis = newDayStart
        nextDayStartMillis = newDayStart + 86_400_000L
        _state.update { it.copy(completedSessions = 0) }
        pomodoroNumber = 1
        sessionRepository.notifyDayChanged()
    }

    suspend fun selectMode(mode: FocusMode) {
        if (_state.value.status != TimerStatus.Idle) return
        val prefs = prefsRepo.preferences.first()
        _state.value = FocusTimerState(
            mode = mode,
            totalMillis = getTotalMillis(mode, FocusPhase.Work, prefs),
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
        savedDayStart: Long = 0L,
    ) {
        // If the day changed since the last save, reset the cycle counter
        val effectiveCompletedSessions = if (savedDayStart != 0L) {
            val currentDay = SessionRepository.startOfDay(System.currentTimeMillis())
            if (savedDayStart != currentDay) {
                currentDayStartMillis = currentDay
                nextDayStartMillis = currentDay + 86_400_000L
                pomodoroNumber = 1
                sessionRepository.notifyDayChanged()
                0
            } else completedSessions
        } else completedSessions

        val prefs = prefsRepo.preferences.first()
        cachedPrefs = prefs
        val resolvedTotal = if (totalMillis > 0L) totalMillis else getTotalMillis(mode, phase, prefs)

        // Restore WaitingForNext without starting timer loop
        if (status == TimerStatus.WaitingForNext) {
            _state.value = FocusTimerState(
                mode = mode,
                phase = phase,
                status = TimerStatus.WaitingForNext,
                totalMillis = resolvedTotal,
                completedSessions = effectiveCompletedSessions,
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
                completedSessions = effectiveCompletedSessions,
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
                completedSessions = effectiveCompletedSessions,
                sessionStartTime = sessionStartTime,
            )
            startTimerLoop()
        }
    }

    fun start() {
        val current = _state.value
        if (current.status == TimerStatus.Running) return

        // Accumulate pause duration when resuming from Paused
        if (current.status == TimerStatus.Paused && pauseStartTime > 0L) {
            totalPauseMillis += System.currentTimeMillis() - pauseStartTime
            pauseStartTime = 0L
        }

        // Reset tracking fields when starting a fresh session
        if (current.status == TimerStatus.Idle || current.status == TimerStatus.WaitingForNext) {
            pauseCount = 0
            pauseStartTime = 0L
            totalPauseMillis = 0L
            interruptionCount = 0
        }

        // Seed completedSessions from DB if starting fresh (Idle or WaitingForNext with 0 sessions)
        if (current.mode == FocusMode.Pomodoro && current.status == TimerStatus.Idle) {
            scope.launch {
                val todayCount = sessionRepository.getTodayPomodoroWorkCount()
                pomodoroNumber = todayCount + 1
                _state.update {
                    it.copy(
                        status = TimerStatus.Running,
                        completedSessions = todayCount,
                        sessionStartTime = if (it.sessionStartTime == 0L) System.currentTimeMillis() else it.sessionStartTime,
                    )
                }
                startTimerLoop()
            }
            return
        }

        _state.update {
            it.copy(
                status = TimerStatus.Running,
                sessionStartTime = if (it.sessionStartTime == 0L) System.currentTimeMillis() else it.sessionStartTime,
            )
        }

        startTimerLoop()
    }

    /**
     * Starts observing preference changes during an active timer session.
     * Updates cachedPrefs and recalculates remaining time if necessary.
     */
    private fun startPrefsObserver() {
        prefsObserverJob?.cancel()
        prefsObserverJob = scope.launch {
            prefsRepo.preferences.collect { newPrefs ->
                val oldPrefs = cachedPrefs
                cachedPrefs = newPrefs

                val s = _state.value
                if (s.status != TimerStatus.Running) return@collect

                // If we're in a timed mode (not Flow/Chrono) and the relevant duration changed,
                // recalculate the total time and check if timer should complete
                if (s.mode != FocusMode.Flow && s.mode != FocusMode.Chrono) {
                    val oldTotalMillis = getTotalMillis(s.mode, s.phase, oldPrefs)
                    val newTotalMillis = getTotalMillis(s.mode, s.phase, newPrefs)

                    // Only update if the settings duration actually changed
                    if (oldTotalMillis != newTotalMillis) {
                        _state.update { it.copy(totalMillis = newTotalMillis) }

                        // If elapsed time already exceeds new duration, complete the phase immediately
                        if (s.elapsedMillis >= newTotalMillis) {
                            onPhaseComplete()
                        }
                    }
                }

                // Also handle Flow mode min minutes changes
                if (s.mode == FocusMode.Flow) {
                    val oldMinMillis = oldPrefs.flowtimeMinMinutes * 60 * 1000L
                    val newMinMillis = newPrefs.flowtimeMinMinutes * 60 * 1000L
                    if (oldMinMillis != newMinMillis && !s.breakSuggested && s.elapsedMillis >= newMinMillis) {
                        _state.update { it.copy(breakSuggested = true) }
                        feedbackManager.onFeedbackPulse()
                    }
                }
            }
        }
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

            // Start observing preference changes during the active session
            startPrefsObserver()

            // 4 Hz tick rate — matches iOS; wall-clock anchoring keeps elapsed accurate regardless
            val tickInterval = 250L
            // Use wall-clock anchoring to avoid drift from delay() imprecision
            val loopStartRealtime = SystemClock.elapsedRealtime()
            val initialElapsed = _state.value.elapsedMillis

            while (true) {
                delay(tickInterval)
                val s = _state.value
                if (s.status != TimerStatus.Running) break

                val newElapsed = initialElapsed + (SystemClock.elapsedRealtime() - loopStartRealtime)
                _state.update { it.copy(elapsedMillis = newElapsed) }

                // Backstop: detect midnight crossing in case the broadcast was missed
                if (System.currentTimeMillis() >= nextDayStartMillis) {
                    onDayChanged()
                }

                // Flowtime: suggest break after minimum session time
                if (s.mode == FocusMode.Flow && !s.breakSuggested) {
                    val minMillis = cachedPrefs.flowtimeMinMinutes * 60 * 1000L
                    if (newElapsed >= minMillis) {
                        _state.update { it.copy(breakSuggested = true) }
                        feedbackManager.onFeedbackPulse()
                    }
                }

                // Blocks: midpoint check-in
                if (s.mode == FocusMode.Blocks && cachedPrefs.midpointCheckIn && !s.midpointTriggered) {
                    if (s.totalMillis > 0 && newElapsed >= s.totalMillis / 2) {
                        _state.update { it.copy(midpointTriggered = true) }
                        feedbackManager.onFeedbackPulse()
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
        prefsObserverJob?.cancel()
        pauseCount++
        pauseStartTime = System.currentTimeMillis()
        _state.update { it.copy(status = TimerStatus.Paused) }
    }

    /** Skip the current phase and advance to the next one (e.g. skip break → start work). */
    fun skipPhase() {
        val s = _state.value
        if (s.status != TimerStatus.Running && s.status != TimerStatus.WaitingForNext) return
        // Only allow skip during break phases (matches iOS behavior)
        if (s.phase != FocusPhase.ShortBreak && s.phase != FocusPhase.LongBreak) return
        timerJob?.cancel()
        scope.launch { onPhaseComplete() }
    }

    fun stop() {
        timerJob?.cancel()
        prefsObserverJob?.cancel()
        // If paused at the time of stop, accumulate remaining pause duration
        if (pauseStartTime > 0L) {
            totalPauseMillis += System.currentTimeMillis() - pauseStartTime
            pauseStartTime = 0L
        }
        val snapshot = _state.value
        scope.launch {
            if (snapshot.elapsedMillis > 0 && snapshot.sessionStartTime > 0) {
                recordSession(snapshot, wasCompleted = false)
            }
            val prefs = prefsRepo.preferences.first()
            _state.value = FocusTimerState(
                mode = snapshot.mode,
                totalMillis = getTotalMillis(snapshot.mode, FocusPhase.Work, prefs),
                linkedTaskId = snapshot.linkedTaskId,
                completedSessions = snapshot.completedSessions, // preserve count for display + next start
            )
        }
    }

    fun linkTask(taskId: String?) {
        _state.update { it.copy(linkedTaskId = taskId) }
    }

    private suspend fun onPhaseComplete() {
        val s = _state.value

        // Sound/haptic/notification feedback on phase completion
        feedbackManager.onPhaseComplete(s.mode, s.phase)

        // Record the completed phase as a session
        recordSession(s, wasCompleted = true)

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
                pomodoroNumber = s.completedSessions + 1
                // Reset pause/interruption tracking for the new work session
                pauseCount = 0
                pauseStartTime = 0L
                totalPauseMillis = 0L
                interruptionCount = 0
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
                    totalMillis = getTotalMillis(FocusMode.Blocks, FocusPhase.Work, prefs),
                    completedSessions = s.completedSessions + 1,
                    linkedTaskId = s.linkedTaskId,
                )
            }

            else -> {
                _state.value = FocusTimerState(
                    mode = s.mode,
                    totalMillis = getTotalMillis(s.mode, FocusPhase.Work, prefs),
                    linkedTaskId = s.linkedTaskId,
                )
            }
        }
    }

    private suspend fun recordSession(s: FocusTimerState, wasCompleted: Boolean = true) {
        if (s.elapsedMillis < 1000) return // ignore sessions shorter than 1 second

        val now = System.currentTimeMillis()
        val targetMillis = if (s.mode == FocusMode.Flow || s.mode == FocusMode.Chrono) null else s.totalMillis
        val sessionId = sessionRepository.recordSession(
            mode = s.mode.name,
            startTime = s.sessionStartTime,
            endTime = now,
            durationMillis = s.elapsedMillis,
            linkedTaskId = s.linkedTaskId,
            phase = s.phase.name,
            wasCompleted = wasCompleted,
            interruptions = interruptionCount,
            pauseCount = pauseCount,
            totalPauseMillis = totalPauseMillis,
            pomodoroNumber = if (s.mode == FocusMode.Pomodoro && s.phase == FocusPhase.Work) pomodoroNumber else null,
            targetDurationMillis = targetMillis,
        )

        // Emit event for work session completion (for journal UI)
        if (sessionId != null && s.phase == FocusPhase.Work) {
            _workSessionCompleted.tryEmit(sessionId)
        }

        // Increment pomodoro count on linked task if this was a work phase
        if (s.linkedTaskId != null && s.phase == FocusPhase.Work) {
            taskRepository.incrementPomodoros(s.linkedTaskId)
        }
    }

    private fun getTotalMillis(mode: FocusMode, phase: FocusPhase, prefs: UserPreferences): Long = when {
        mode == FocusMode.Pomodoro && phase == FocusPhase.Work -> prefs.pomodoroMinutes * 60 * 1000L
        mode == FocusMode.Pomodoro && phase == FocusPhase.ShortBreak -> prefs.shortBreakMinutes * 60 * 1000L
        mode == FocusMode.Pomodoro && phase == FocusPhase.LongBreak -> prefs.longBreakMinutes * 60 * 1000L
        mode == FocusMode.Blocks -> prefs.timeBlockMinutes * 60 * 1000L
        else -> 0L
    }
}
