package dev.creapolis.pepinillo.feature.focus

import android.content.Context
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import dagger.hilt.android.lifecycle.HiltViewModel
import dagger.hilt.android.qualifiers.ApplicationContext
import dev.creapolis.pepinillo.R
import dev.creapolis.pepinillo.core.billing.FeatureGate
import dev.creapolis.pepinillo.data.local.preferences.UserPreferencesRepository
import dev.creapolis.pepinillo.data.repository.SessionRepository
import dev.creapolis.pepinillo.data.repository.TaskRepository
import dev.creapolis.pepinillo.domain.soundscape.Soundscape
import dev.creapolis.pepinillo.domain.soundscape.SoundscapeManager
import dev.creapolis.pepinillo.domain.timer.FocusEngine
import dev.creapolis.pepinillo.domain.timer.FocusPhase
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
)

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
    private var _lastCompletedSessionId: String? = null
    private val _successMessage = MutableStateFlow<Int?>(null)
    val successMessage: StateFlow<Int?> = _successMessage.asStateFlow()
    val showTaskPicker: StateFlow<Boolean> = _showTaskPicker.asStateFlow()

    val activeTasks: StateFlow<List<Task>> = taskRepository.getActiveTasks()
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), emptyList())

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

        // Watch engine state to manage foreground service lifecycle
        viewModelScope.launch {
            focusEngine.state.collect { state ->
                when (state.status) {
                    TimerStatus.Running -> FocusTimerService.start(context)
                    TimerStatus.WaitingForNext -> FocusTimerService.start(context)
                    TimerStatus.Idle -> FocusTimerService.stop(context)
                    TimerStatus.Paused -> { /* service stays alive while paused */ }
                }
            }
        }

        // Manage soundscape playback tied to timer lifecycle
        viewModelScope.launch {
            var wasRunningOrPaused = false
            focusEngine.state.collect { state ->
                val isActive = state.status == TimerStatus.Running || state.status == TimerStatus.Paused
                val soundscape = _selectedSoundscape.value
                val volume = _soundscapeVolume.value

                when {
                    // Timer just started → play soundscape
                    state.status == TimerStatus.Running && !wasRunningOrPaused && soundscape != null -> {
                        soundscapeManager.play(soundscape, volume)
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

    val uiState: StateFlow<FocusUiState> = combine(
        combine(
            focusEngine.state,
            sessionRepository.getTodaySessionCount(),
            sessionRepository.getAllDaysWithSessions(),
            _linkedTaskName,
            _showTaskPicker,
        ) { timerState, todayCount, allDays, linkedTaskName, showPicker ->
            TimerCombined(timerState, todayCount, allDays, linkedTaskName, showPicker)
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
        ) { soundscape, volume, showPicker ->
            SoundscapeCombined(soundscape, volume, showPicker)
        },
    ) { combined, settings, soundscape ->
        FocusUiState(
            selectedMode = combined.timerState.mode,
            displayTime = combined.timerState.displayTime,
            progress = combined.timerState.progress,
            phaseLabelRes = combined.timerState.phaseLabelRes,
            currentPhase = combined.timerState.phase,
            isRunning = combined.timerState.status == TimerStatus.Running,
            isPaused = combined.timerState.status == TimerStatus.Paused,
            linkedTaskName = combined.linkedTaskName,
            sessionsToday = combined.todayCount,
            currentStreak = sessionRepository.calculateCurrentStreak(combined.allDays),
            greetingRes = computeGreetingRes(),
            currentDate = computeDate(),
            showTaskPicker = combined.showPicker,
            showStopConfirmation = settings.showStopConfirm,
            keepScreenOn = settings.prefs.keepScreenOn,
            breakSuggested = combined.timerState.breakSuggested,
            isWaitingForNext = combined.timerState.status == TimerStatus.WaitingForNext,
            canSkip = combined.timerState.mode == FocusMode.Pomodoro &&
                (combined.timerState.status == TimerStatus.Running || combined.timerState.status == TimerStatus.WaitingForNext) &&
                (combined.timerState.phase == FocusPhase.ShortBreak || combined.timerState.phase == FocusPhase.LongBreak),
            isPro = settings.subState.hasLocalPremium,
            showPaywall = settings.showPaywall,
            showJournalSheet = settings.showJournal,
            selectedSoundscape = soundscape.soundscape,
            soundscapeVolume = soundscape.volume,
            showSoundscapePicker = soundscape.showPicker,
            completedSessions = combined.timerState.completedSessions,
        )
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), FocusUiState(
        greetingRes = computeGreetingRes(),
        currentDate = computeDate(),
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
            TimerStatus.Idle -> focusEngine.start()
            TimerStatus.Running -> focusEngine.pause()
            TimerStatus.Paused -> focusEngine.start()
            TimerStatus.WaitingForNext -> focusEngine.start()
        }
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
        _soundscapeVolume.value = volume.coerceIn(0f, 1f)
        val state = focusEngine.state.value
        if (state.status == TimerStatus.Running || state.status == TimerStatus.Paused) {
            soundscapeManager.setVolume(volume)
        }
    }

    private data class TimerCombined(
        val timerState: dev.creapolis.pepinillo.domain.timer.FocusTimerState,
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
}
