package dev.creapolis.pepinillo.feature.focus

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.PowerManager
import android.provider.Settings
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import dagger.hilt.android.lifecycle.HiltViewModel
import dagger.hilt.android.qualifiers.ApplicationContext
import dev.creapolis.pepinillo.R
import dev.creapolis.pepinillo.core.billing.FeatureGate
import dev.creapolis.pepinillo.data.local.preferences.UserPreferencesRepository
import dev.creapolis.pepinillo.data.repository.SessionRepository
import dev.creapolis.pepinillo.domain.streak.StreakProtectionService
import dev.creapolis.pepinillo.data.repository.TaskRepository
import dev.creapolis.pepinillo.domain.soundscape.Soundscape
import dev.creapolis.pepinillo.domain.soundscape.SoundscapeManager
import dev.creapolis.pepinillo.domain.timer.FocusEngine
import dev.creapolis.pepinillo.domain.timer.FocusPhase
import dev.creapolis.pepinillo.domain.timer.FailedSession
import dev.creapolis.pepinillo.domain.timer.TimerStatus
import dev.creapolis.pepinillo.domain.timer.displayTime
import dev.creapolis.pepinillo.domain.timer.phaseLabelRes
import dev.creapolis.pepinillo.domain.timer.progress
import dev.creapolis.pepinillo.feature.tasks.model.Task
import dev.creapolis.pepinillo.service.FocusTimerService
import dev.creapolis.pepinillo.wear.WearDataLayerHelper
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.conflate
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.sample
import kotlin.time.Duration.Companion.seconds
import kotlinx.coroutines.flow.first
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
    val phaseLabelRes: Int = R.string.phase_focus,
    val currentPhase: FocusPhase = FocusPhase.Work,
    val isRunning: Boolean = false,
    val isPaused: Boolean = false,
    val linkedTaskName: String? = null,
    val sessionsToday: Int = 0,
    val currentStreak: Int = 0,
    val greetingRes: Int = R.string.greeting_morning,
    val currentDate: String = "",
    val showTaskPicker: Boolean = false,
    val showStopConfirmation: Boolean = false,
    val keepScreenOn: Boolean = false,
    val breakSuggested: Boolean = false,
    val isWaitingForNext: Boolean = false,
    val canSkip: Boolean = false,
    val isPro: Boolean = false,
    val showPaywall: Boolean = false,
    val showJournalSheet: Boolean = false,
    val selectedSoundscape: Soundscape? = null,
    val soundscapeVolume: Float = 0.5f,
    val showSoundscapePicker: Boolean = false,
    val completedSessions: Int = 0,
    val sessionsBeforeLongBreak: Int = 4,
    val showBatteryWarningDialog: Boolean = false,
    /** Master toggle for all UI haptics; mirrors [dev.creapolis.pepinillo.data.local.preferences.UserPreferences.vibrationEnabled]. */
    val vibrationEnabled: Boolean = true,
)

/**
 * Minimal high-rate projection of [FocusTimerState] for the hero timer ring and the live time
 * text. Kept intentionally small so [FocusViewModel.ringState] can emit at the engine's native
 * 4Hz tick without re-running the heavy [FocusViewModel.uiState] combine.
 *
 * Polarity matches [FocusTimerState.progress]: `progress` is the *remaining* fraction for
 * countdown modes (1f = full ring, 0f = done); count-up modes report an elapsed/1h fraction.
 */
data class RingState(
    val progress: Float = 1f,
    val displayTime: String = "25:00",
    val isRunning: Boolean = false,
    val isPaused: Boolean = false,
)

/**
 * Screen-reader projection of the hero timer (super-review F1). Updated at a TalkBack-friendly
 * cadence — the announced minute changes at most once per minute, and phase/mode changes are
 * included so screen-reader users hear transitions without a 4Hz chatter.
 */
data class FocusA11yState(
    val phaseLabelRes: Int = R.string.phase_focus,
    val mode: FocusMode = FocusMode.Pomodoro,
    val minutes: Int = 25,
)

/**
 * Whole-minute value for the timer's accessibility announcement. Countdown modes round up (a
 * visible 24:59 still reads "25 min" until it ticks past the minute), so the announced value
 * changes exactly once per minute; count-up modes round down.
 */
internal fun a11yMinutes(mode: FocusMode, elapsedMillis: Long, totalMillis: Long): Int {
    val millis = when (mode) {
        FocusMode.Flow, FocusMode.Chrono -> elapsedMillis
        else -> (totalMillis - elapsedMillis).coerceAtLeast(0L)
    }
    return if (mode == FocusMode.Flow || mode == FocusMode.Chrono) {
        (millis / 60_000L).toInt()
    } else {
        ((millis + 59_999L) / 60_000L).toInt()
    }
}

@HiltViewModel
class FocusViewModel @Inject constructor(
    @ApplicationContext private val context: Context,
    private val focusEngine: FocusEngine,
    private val sessionRepository: SessionRepository,
    private val taskRepository: TaskRepository,
    private val prefsRepo: UserPreferencesRepository,
    private val featureGate: FeatureGate,
    private val soundscapeManager: SoundscapeManager,
) : ViewModel() {

    private val _linkedTaskName = MutableStateFlow<String?>(null)
    private val _showTaskPicker = MutableStateFlow(false)
    private val _showStopConfirmation = MutableStateFlow(false)
    private val _showPaywall = MutableStateFlow(false)
    private val _showJournalSheet = MutableStateFlow(false)
    private val _selectedSoundscape = MutableStateFlow<Soundscape?>(null)
    private val _soundscapeVolume = MutableStateFlow(0.5f)
    private val _showSoundscapePicker = MutableStateFlow(false)
    private val _showBatteryWarningDialog = MutableStateFlow(false)
    private var _lastCompletedSessionId: String? = null
    private val _successMessage = MutableStateFlow<Int?>(null)
    val successMessage: StateFlow<Int?> = _successMessage.asStateFlow()
    val showTaskPicker: StateFlow<Boolean> = _showTaskPicker.asStateFlow()

    /** Retains the last session whose save failed, so the user can retry via the snackbar. */
    private val _lastFailedSession = MutableStateFlow<FailedSession?>(null)
    val lastFailedSession: StateFlow<FailedSession?> = _lastFailedSession.asStateFlow()

    val activeTasks: StateFlow<List<Task>> = taskRepository.getActiveTasks()
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), emptyList())

    /**
     * Live engine snapshot at ViewModel creation. When this screen's
     * destination is destroyed by a tab switch (Compose Navigation disposes
     * it; only rememberSaveable survives) and recreated mid-session, the
     * flows below must already reflect the running session on their very
     * first emission — otherwise the screen morphs Idle→Running and replays
     * the start animation (iOS keeps this state, so must we).
     */
    private val entryEngineSnapshot = focusEngine.state.value
    private val entryStatus: TimerStatus = entryEngineSnapshot.status

    init {
        // Load default mode from preferences on first launch
        viewModelScope.launch {
            val prefs = prefsRepo.preferences.first()
            val engineState = focusEngine.state.value
            if (engineState.status == TimerStatus.Idle
                && engineState.completedSessions == 0
                && engineState.phase == FocusPhase.Work
            ) {
                val defaultMode = FocusMode.entries.find { it.name == prefs.defaultMode }
                    ?: FocusMode.Pomodoro
                focusEngine.selectMode(defaultMode)
            }
            
            // Push initial state to Wear OS
            val currentState = focusEngine.state.value
            val linkedTaskName = currentState.linkedTaskId?.let { taskRepository.getTaskById(it)?.title }
            WearDataLayerHelper.pushTimer(context, currentState, linkedTaskName)
        }

        // Watch engine state to manage foreground service lifecycle.
        // A-C5: Only react to STATUS TRANSITIONS, not every 100ms tick emission.
        // Calling FocusTimerService.start(context) on every Running/WaitingForNext
        // tick fired a redundant startForegroundService + onStartCommand + startForeground
        // 10x/second, and rapid play/pause toggles could leave multiple startForegroundService
        // calls in flight with no startForeground between them -> RemoteServiceException on
        // Android 12+.
        viewModelScope.launch {
            var previousStatus: TimerStatus? = null
            focusEngine.state.collect { state ->
                if (state.status == previousStatus) return@collect
                previousStatus = state.status
                when (state.status) {
                    TimerStatus.Running -> FocusTimerService.start(context)
                    TimerStatus.WaitingForNext -> FocusTimerService.start(context)
                    TimerStatus.Idle -> FocusTimerService.stop(context)
                    TimerStatus.Paused -> { /* service stays alive while paused */ }
                }
            }
        }

        // Surface session-save failures so the UI can offer retry instead of silent data loss.
        viewModelScope.launch {
            focusEngine.sessionSaveFailed.collect { failed ->
                _lastFailedSession.value = failed
            }
        }

        viewModelScope.launch {
            val prefs = prefsRepo.preferences.first()
            val restoredSoundscape = prefs.selectedSoundscape?.let { name ->
                Soundscape.entries.find { it.name == name }
            }
            _selectedSoundscape.value = restoredSoundscape
            _soundscapeVolume.value = prefs.soundscapeVolume
        }

        // Manage soundscape playback tied to timer lifecycle
        viewModelScope.launch {
            var wasRunningOrPaused = false
            focusEngine.state.collect { state ->
                val isActive = state.status == TimerStatus.Running || state.status == TimerStatus.Paused
                val soundscape = _selectedSoundscape.value
                val volume = _soundscapeVolume.value

                when {
                    // Timer is running → play the selected soundscape. Compared against the
                    // *selected* soundscape (not just null-checking the manager): a switch made
                    // while WaitingForNext must apply when the next phase starts, even if the
                    // previous soundscape is still loaded (fade-out in flight).
                    state.status == TimerStatus.Running && soundscape != null &&
                        soundscapeManager.currentSoundscape != soundscape -> {
                        soundscapeManager.play(soundscape, volume)
                    }
                    // Phase completed and waiting for user to start the next one → fade out.
                    // WaitingForNext is only reached when auto-start is OFF (FocusEngine transitions
                    // straight to Running when autoStartBreaks/autoStartNextPomodoro are on), so the
                    // user expects silence here rather than continuous ambient (#525).
                    state.status == TimerStatus.WaitingForNext && wasRunningOrPaused -> {
                        soundscapeManager.fadeOut()
                    }
                    // Timer stopped/completed → fade out soundscape
                    state.status == TimerStatus.Idle && wasRunningOrPaused -> {
                        soundscapeManager.fadeOut()
                    }
                    // Soundscape continues during pause (don't stop)
                }
                wasRunningOrPaused = isActive
            }
        }

        // Show journal sheet when a work session completes (if enabled)
        viewModelScope.launch {
            focusEngine.workSessionCompleted.collect { sessionId ->
                _lastCompletedSessionId = sessionId
                val prefs = prefsRepo.preferences.first()
                if (prefs.showJournalAfterSession) {
                    _showJournalSheet.value = true
                }
            }
        }

        // Resolve linked task name when engine state changes
        viewModelScope.launch {
            focusEngine.state.collect { state ->
                val taskId = state.linkedTaskId
                if (taskId != null) {
                    val task = taskRepository.getTaskById(taskId)
                    if (task != null) {
                        _linkedTaskName.value = task.title
                    } else {
                        // Task was deleted — auto-unlink
                        focusEngine.linkTask(null)
                        _linkedTaskName.value = null
                    }
                } else {
                    _linkedTaskName.value = null
                }
            }
        }
    }

    // ── Soundscape ──

    /** Status transitions bypass the 1Hz sample below so play/pause UI reacts instantly. */
    private val statusFlow = focusEngine.state
        .map { it.status }
        .distinctUntilChanged()

    val uiState: StateFlow<FocusUiState> = combine(
        combine(
            combine(
                // Sample the ticking engine state at most once per second (4Hz → 1Hz) for the uiState
                // combine. The heavy combine (settings/soundscape/tasks/session history) only needs
                // ~1Hz granularity — this cuts body recomposition ~75%. The hero timer ring and the
                // live display time read the dedicated high-rate `ringState` flow below instead, so
                // they animate smoothly at the engine's native 4Hz without re-running this combine.
                focusEngine.state.sample(1.seconds),
                // Status is NOT sampled: isRunning/isPaused/isWaitingForNext drive the primary
                // button, so a status flip must reach the UI immediately instead of lagging up
                // to ~1s behind the sample window (super-review micro-fix).
                statusFlow,
            ) { sampledState, status -> sampledState to status },
            sessionRepository.getTodaySessionCount(),
            sessionRepository.getAllDaysWithSessions(),
            _linkedTaskName,
            _showTaskPicker,
        ) { timerStateWithStatus, todayCount, allDays, linkedTaskName, showPicker ->
            TimerCombined(
                timerState = timerStateWithStatus.first,
                status = timerStateWithStatus.second,
                todayCount = todayCount,
                allDays = allDays,
                linkedTaskName = linkedTaskName,
                showPicker = showPicker,
            )
        },
        combine(
            prefsRepo.preferences,
            _showStopConfirmation,
            featureGate.subscriptionState,
            _showPaywall,
            _showJournalSheet,
        ) { prefs, showStopConfirm, subState, showPaywall, showJournal ->
            SettingsCombined(prefs, showStopConfirm, subState, showPaywall, showJournal)
        },
        combine(
            _selectedSoundscape,
            _soundscapeVolume,
            _showSoundscapePicker,
            _showBatteryWarningDialog,
        ) { soundscape, volume, showPicker, showBatteryWarning ->
            SoundscapeCombined(soundscape, volume, showPicker, showBatteryWarning)
        },
    ) { combined, settings, soundscape ->
        FocusUiState(
            selectedMode = combined.timerState.mode,
            displayTime = combined.timerState.displayTime,
            progress = combined.timerState.progress,
            phaseLabelRes = combined.timerState.phaseLabelRes,
            currentPhase = combined.timerState.phase,
            isRunning = combined.status == TimerStatus.Running,
            isPaused = combined.status == TimerStatus.Paused,
            linkedTaskName = combined.linkedTaskName,
            sessionsToday = combined.todayCount,
            currentStreak = StreakProtectionService.computeProtectedStreak(
                history = combined.allDays,
                isPro = settings.subState.hasLocalPremium,
            ).days,
            greetingRes = computeGreetingRes(),
            currentDate = computeDate(),
            showTaskPicker = combined.showPicker,
            showStopConfirmation = settings.showStopConfirm,
            keepScreenOn = settings.prefs.keepScreenOn,
            breakSuggested = combined.timerState.breakSuggested,
            isWaitingForNext = combined.status == TimerStatus.WaitingForNext,
            canSkip = combined.timerState.mode == FocusMode.Pomodoro &&
                (combined.status == TimerStatus.Running || combined.status == TimerStatus.WaitingForNext) &&
                (combined.timerState.phase == FocusPhase.ShortBreak || combined.timerState.phase == FocusPhase.LongBreak),
            isPro = settings.subState.hasLocalPremium,
            showPaywall = settings.showPaywall,
            showJournalSheet = settings.showJournal,
            selectedSoundscape = soundscape.soundscape,
            soundscapeVolume = soundscape.volume,
            showSoundscapePicker = soundscape.showPicker,
            completedSessions = combined.timerState.completedSessions,
            sessionsBeforeLongBreak = settings.prefs.sessionsBeforeLongBreak,
            showBatteryWarningDialog = soundscape.showBatteryWarning,
            vibrationEnabled = settings.prefs.vibrationEnabled,
        )
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), FocusUiState(
        greetingRes = computeGreetingRes(),
        currentDate = computeDate(),
        // Tab-return seed (see entryEngineSnapshot): a ViewModel created
        // mid-session must render Running on its first emission, or the
        // screen replays the start animation.
        selectedMode = entryEngineSnapshot.mode,
        displayTime = entryEngineSnapshot.displayTime,
        progress = entryEngineSnapshot.progress,
        phaseLabelRes = entryEngineSnapshot.phaseLabelRes,
        currentPhase = entryEngineSnapshot.phase,
        isRunning = entryStatus == TimerStatus.Running,
        isPaused = entryStatus == TimerStatus.Paused,
        isWaitingForNext = entryStatus == TimerStatus.WaitingForNext,
        breakSuggested = entryEngineSnapshot.breakSuggested,
        canSkip = entryEngineSnapshot.mode == FocusMode.Pomodoro &&
            (entryStatus == TimerStatus.Running || entryStatus == TimerStatus.WaitingForNext) &&
            (entryEngineSnapshot.phase == FocusPhase.ShortBreak || entryEngineSnapshot.phase == FocusPhase.LongBreak),
    ))

    /**
     * High-rate view of the timer state for the hero ring + live time text (#505).
     *
     * Reads the unsampled [FocusEngine.state] (4Hz tick) and projects only the fields the ring
     * surface needs. [conflate] keeps the latest value so a slow consumer never backpressures the
     * engine; [distinctUntilChanged] on the projected [RingState] drops no-op emissions (e.g.
     * midpoint/break-suggested flag flips that don't change progress or displayTime).
     *
     * The rest of the screen keeps reading [uiState] at 1Hz — this flow exists precisely so the
     * ring doesn't chop once per second while the dashboard combine stays cheap.
     */
    val ringState: StateFlow<RingState> = focusEngine.state
        .map { state ->
            RingState(
                progress = state.progress,
                displayTime = state.displayTime,
                isRunning = state.status == TimerStatus.Running,
                isPaused = state.status == TimerStatus.Paused,
            )
        }
        .distinctUntilChanged()
        .conflate()
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), RingState(
            progress = entryEngineSnapshot.progress,
            displayTime = entryEngineSnapshot.displayTime,
            isRunning = entryStatus == TimerStatus.Running,
            isPaused = entryStatus == TimerStatus.Paused,
        ))

    /**
     * Screen-reader view of the timer for the hero ring's content description (super-review F1):
     * minute-granular time plus phase/mode, derived from the 1Hz-sampled engine state and
     * de-duplicated, so the live region announces at most once per minute and on phase changes.
     */
    val a11yState: StateFlow<FocusA11yState> = focusEngine.state
        .sample(1.seconds)
        .map { state ->
            FocusA11yState(
                phaseLabelRes = state.phaseLabelRes,
                mode = state.mode,
                minutes = a11yMinutes(state.mode, state.elapsedMillis, state.totalMillis),
            )
        }
        .distinctUntilChanged()
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), FocusA11yState(
            phaseLabelRes = entryEngineSnapshot.phaseLabelRes,
            mode = entryEngineSnapshot.mode,
            minutes = a11yMinutes(entryEngineSnapshot.mode, entryEngineSnapshot.elapsedMillis, entryEngineSnapshot.totalMillis),
        ))

    fun selectMode(mode: FocusMode) {
        if (!featureGate.canUseMode(mode)) {
            _showPaywall.value = true
            return
        }
        viewModelScope.launch {
            focusEngine.selectMode(mode)
            val state = focusEngine.state.value
            WearDataLayerHelper.pushTimer(context, state, null)
        }
    }

    fun dismissPaywall() {
        _showPaywall.value = false
    }

    fun onStartStopClick() {
        val state = focusEngine.state.value
        when (state.status) {
            TimerStatus.Idle -> {
                if (!isIgnoringBatteryOptimizations()) {
                    _showBatteryWarningDialog.value = true
                } else {
                    focusEngine.start()
                }
            }
            TimerStatus.Running -> focusEngine.pause()
            TimerStatus.Paused -> focusEngine.start()
            TimerStatus.WaitingForNext -> focusEngine.start()
        }
    }

    fun startTimerAnyway() {
        _showBatteryWarningDialog.value = false
        focusEngine.start()
    }

    fun dismissBatteryWarning() {
        _showBatteryWarningDialog.value = false
    }

    fun openBatterySettings() {
        _showBatteryWarningDialog.value = false

        try {
            val intent = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
            }
            context.startActivity(intent)
        } catch (e: Exception) {
            try {
                val fallbackIntent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                    data = Uri.parse("package:${context.packageName}")
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                }
                context.startActivity(fallbackIntent)
            } catch (ex: Exception) {
                // Ignore if settings can't be opened
            }
        }
    }

    private fun isIgnoringBatteryOptimizations(): Boolean {
        val powerManager = context.getSystemService(Context.POWER_SERVICE) as PowerManager
        return powerManager.isIgnoringBatteryOptimizations(context.packageName)
    }

    fun onStopClick() {
        _showStopConfirmation.value = true
    }

    fun confirmStop() {
        _showStopConfirmation.value = false
        focusEngine.stop()
    }

    fun dismissStopConfirmation() {
        _showStopConfirmation.value = false
    }

    fun onSkipClick() {
        focusEngine.skipPhase()
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
        if (taskId != null) {
            _successMessage.value = R.string.msg_task_linked
        }
        
        // Sync with widgets immediately
        viewModelScope.launch {
            dev.creapolis.pepinillo.widget.WidgetTaskStateManager.updateLinkedTaskId(context, taskId)
        }
    }

    fun dismissSuccessMessage() {
        _successMessage.value = null
    }

    fun saveJournalEntry(note: String?, rating: Int?) {
        val sessionId = _lastCompletedSessionId ?: return
        viewModelScope.launch {
            sessionRepository.saveJournalEntry(sessionId, note, rating)
            _showJournalSheet.value = false
            _lastCompletedSessionId = null
        }
    }

    fun skipJournal() {
        _showJournalSheet.value = false
        _lastCompletedSessionId = null
    }

    // ── Soundscape ──

    fun onSoundscapePickerClick() {
        _showSoundscapePicker.value = true
    }

    fun dismissSoundscapePicker() {
        _showSoundscapePicker.value = false
    }

    fun selectSoundscape(soundscape: Soundscape?) {
        _selectedSoundscape.value = soundscape
        _showSoundscapePicker.value = false

        viewModelScope.launch {
            prefsRepo.updateSelectedSoundscape(soundscape?.name)
        }

        // If the timer is currently running, start/stop the soundscape immediately
        val state = focusEngine.state.value
        if (state.status == TimerStatus.Running || state.status == TimerStatus.Paused) {
            if (soundscape != null) {
                soundscapeManager.play(soundscape, _soundscapeVolume.value)
            } else {
                soundscapeManager.fadeOut()
            }
        }
    }

    fun setSoundscapeVolume(volume: Float) {
        val clamped = volume.coerceIn(0f, 1f)
        _soundscapeVolume.value = clamped
        viewModelScope.launch {
            prefsRepo.updateSoundscapeVolume(clamped)
        }
        val state = focusEngine.state.value
        if (state.status == TimerStatus.Running || state.status == TimerStatus.Paused) {
            soundscapeManager.setVolume(clamped)
        }
    }

    private data class TimerCombined(
        val timerState: dev.creapolis.pepinillo.domain.timer.FocusTimerState,
        val status: TimerStatus,
        val todayCount: Int,
        val allDays: List<dev.creapolis.pepinillo.data.local.entity.DailyStatsEntity>,
        val linkedTaskName: String?,
        val showPicker: Boolean,
    )

    private data class SettingsCombined(
        val prefs: dev.creapolis.pepinillo.data.local.preferences.UserPreferences,
        val showStopConfirm: Boolean,
        val subState: dev.creapolis.pepinillo.core.billing.SubscriptionState,
        val showPaywall: Boolean,
        val showJournal: Boolean,
    )

    private data class SoundscapeCombined(
        val soundscape: Soundscape?,
        val volume: Float,
        val showPicker: Boolean,
        val showBatteryWarning: Boolean,
    )

    private fun computeGreetingRes(): Int {
        val hour = Calendar.getInstance().get(Calendar.HOUR_OF_DAY)
        return when {
            hour < 12 -> R.string.greeting_morning
            hour < 18 -> R.string.greeting_afternoon
            else -> R.string.greeting_evening
        }
    }

    private fun computeDate(): String {
        val dateFormat = SimpleDateFormat("EEEE, MMMM d", Locale.getDefault())
        return dateFormat.format(Date())
    }

    /** Re-attempt persisting the last failed session; clears the failure state on success. */
    fun retrySessionSave() {
        val failed = _lastFailedSession.value ?: return
        viewModelScope.launch {
            val newId = focusEngine.retrySaveSession(failed)
            if (newId != null) {
                _lastFailedSession.value = null
                _successMessage.value = R.string.msg_session_saved
            }
        }
    }

    fun dismissSessionSaveError() {
        _lastFailedSession.value = null
    }
}
