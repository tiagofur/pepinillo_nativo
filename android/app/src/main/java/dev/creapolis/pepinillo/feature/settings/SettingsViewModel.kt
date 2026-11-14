package dev.creapolis.pepinillo.feature.settings

import android.content.Context
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope

import dagger.hilt.android.lifecycle.HiltViewModel
import dagger.hilt.android.qualifiers.ApplicationContext
import dev.creapolis.pepinillo.BuildConfig
import dev.creapolis.pepinillo.core.billing.FeatureGate
import dev.creapolis.pepinillo.core.billing.SubscriptionTier
import dev.creapolis.pepinillo.core.auth.AuthStore
import dev.creapolis.pepinillo.core.billing.SubscriptionState
import dev.creapolis.pepinillo.data.local.entity.DailyStatsEntity
import dev.creapolis.pepinillo.domain.streak.StreakProtectionService
import dev.creapolis.pepinillo.core.network.UpdateProfileRequest
import dev.creapolis.pepinillo.data.local.preferences.UserPreferences
import dev.creapolis.pepinillo.data.local.preferences.UserPreferencesRepository
import dev.creapolis.pepinillo.data.repository.SessionRepository
import dev.creapolis.pepinillo.data.repository.UserRepository
import dev.creapolis.pepinillo.data.sync.SyncState
import dev.creapolis.pepinillo.data.sync.SyncStatusManager
import dev.creapolis.pepinillo.feature.focus.FocusMode
import dev.creapolis.pepinillo.service.DailyReminderScheduler
import dev.creapolis.pepinillo.service.WeeklyRecapScheduler
import dev.creapolis.pepinillo.ui.theme.AppTheme
import dev.creapolis.pepinillo.ui.theme.ThemeController
import dev.creapolis.pepinillo.ui.theme.ThemeMode
import dev.creapolis.pepinillo.wear.WearDataLayerHelper
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import javax.inject.Inject

private const val METRICS_OPT_IN_ERROR_MESSAGE =
    "No se pudo actualizar tu preferencia de privacidad. Inténtalo de nuevo."

data class SettingsUiState(
    val pomodoroMinutes: Int = 25,
    val shortBreakMinutes: Int = 5,
    val longBreakMinutes: Int = 15,
    val sessionsBeforeLongBreak: Int = 4,
    val timeBlockMinutes: Int = 60,
    val autoStartBreaks: Boolean = true,
    val autoStartNextPomodoro: Boolean = false,
    val soundEnabled: Boolean = true,
    val vibrationEnabled: Boolean = true,
    val themeMode: ThemeMode = ThemeMode.System,
    val dynamicColor: Boolean = true,
    val appVersion: String = "${BuildConfig.VERSION_NAME} (${BuildConfig.VERSION_CODE})",
    val flowtimeMinMinutes: Int = 5,
    val defaultMode: FocusMode = FocusMode.Pomodoro,
    val keepScreenOn: Boolean = false,
    val dailyReminderEnabled: Boolean = false,
    val dailyReminderHour: Int = 9,
    val dailyReminderMinute: Int = 0,
    val midpointCheckIn: Boolean = false,
    val timerNotificationsEnabled: Boolean = true,
    val showJournalAfterSession: Boolean = true,
    val hapticTimerTickEnabled: Boolean = false,
    val selectedTheme: String = "materialYou",
    val currentStreak: Int = 0,
    val celebrateStreakRecords: Boolean = true,
    val weeklyRecapEnabled: Boolean = false,
    val isPro: Boolean = false,
    val subscriptionTier: SubscriptionTier = SubscriptionTier.FREE,
    // Sync status
    val isOnline: Boolean = true,
    val syncState: SyncState = SyncState.Idle,
    val lastSyncAt: Long? = null,
    val pendingChangesCount: Int = 0,
    val isLoggedIn: Boolean = false,
    val metricsOptIn: Boolean = false,
    val isUpdatingMetricsOptIn: Boolean = false,
    val metricsOptInError: String? = null,
)

@HiltViewModel
class SettingsViewModel @Inject constructor(
    @ApplicationContext private val context: Context,
    private val prefsRepo: UserPreferencesRepository,
    private val sessionRepository: SessionRepository,
    private val featureGate: FeatureGate,
    private val syncStatusManager: SyncStatusManager,
    private val authStore: AuthStore,
    private val userRepository: UserRepository,
) : ViewModel() {

    private val _metricsOptIn = MutableStateFlow(false)
    private val _isUpdatingMetricsOptIn = MutableStateFlow(false)
    private val _metricsOptInError = MutableStateFlow<String?>(null)

    @Suppress("UNCHECKED_CAST")
    val uiState: StateFlow<SettingsUiState> = combine(
        flows = arrayOf(
            prefsRepo.preferences,
            sessionRepository.getAllDaysWithSessions(),
            featureGate.subscriptionState,
            syncStatusManager.isOnline,
            syncStatusManager.syncState,
            syncStatusManager.lastSyncAt,
            syncStatusManager.pendingChangesCount,
            authStore.isLoggedIn,
            _metricsOptIn,
            _isUpdatingMetricsOptIn,
            _metricsOptInError,
        ),
    ) { values ->
        val prefs = values[0] as UserPreferences
        val allDays = values[1] as List<DailyStatsEntity>
        val subState = values[2] as SubscriptionState
        val isOnline = values[3] as Boolean
        val syncState = values[4] as SyncState
        val lastSyncAt = values[5] as Long?
        val pendingChangesCount = values[6] as Int
        val isLoggedIn = values[7] as Boolean
        val metricsOptIn = values[8] as Boolean
        val isUpdatingMetricsOptIn = values[9] as Boolean
        val metricsOptInError = values[10] as String?

        prefs.toUiState(
            currentStreak = StreakProtectionService.computeProtectedStreak(
                history = allDays,
                isPro = subState.hasLocalPremium,
            ).days,
            isPro = subState.hasLocalPremium,
            subscriptionTier = subState.tier,
            isOnline = isOnline,
            syncState = syncState,
            lastSyncAt = lastSyncAt,
            pendingChangesCount = pendingChangesCount,
            isLoggedIn = isLoggedIn,
            metricsOptIn = if (isLoggedIn) metricsOptIn else false,
            isUpdatingMetricsOptIn = if (isLoggedIn) isUpdatingMetricsOptIn else false,
            metricsOptInError = if (isLoggedIn) metricsOptInError else null,
        )
    }.stateIn(viewModelScope, SharingStarted.Eagerly, SettingsUiState())

    init {
        // Sync theme controller with persisted preferences
        viewModelScope.launch {
            prefsRepo.preferences.collect { prefs ->
                ThemeController.setThemeMode(prefs.themeMode)
                ThemeController.setDynamicColor(prefs.dynamicColor)
                ThemeController.setSelectedTheme(prefs.selectedTheme)

                // Push theme to Wear OS
                val theme = AppTheme.named(prefs.selectedTheme)
                WearDataLayerHelper.pushTheme(context, prefs.selectedTheme, theme)
            }
        }

        // Keep _metricsOptIn synchronized when UserRepository.metricsOptIn updates (e.g. from Wear OS)
        viewModelScope.launch {
            userRepository.metricsOptIn.collect { repoOptIn ->
                if (!_isUpdatingMetricsOptIn.value && uiState.value.isLoggedIn) {
                    _metricsOptIn.value = repoOptIn
                }
            }
        }

        // Load real server metricsOptIn when logged in; reset to OFF when logged out
        viewModelScope.launch {
            authStore.isLoggedIn.collect { loggedIn ->
                if (loggedIn) {
                    refreshMetricsOptIn()
                } else {
                    _metricsOptIn.value = false
                    _isUpdatingMetricsOptIn.value = false
                    _metricsOptInError.value = null
                    WearDataLayerHelper.pushUserStatus(
                        context = context,
                        isPro = uiState.value.isPro,
                        sessionsBeforeLongBreak = uiState.value.sessionsBeforeLongBreak,
                        isLoggedIn = false,
                        metricsOptIn = false,
                    )
                }
            }
        }
    }

    fun refreshMetricsOptIn() {
        viewModelScope.launch {
            if (!uiState.value.isLoggedIn) {
                _metricsOptIn.value = false
                return@launch
            }
            userRepository.fetchAndCacheProfile().onSuccess {
                val optedIn = userRepository.metricsOptIn.value
                _metricsOptIn.value = optedIn
                WearDataLayerHelper.pushUserStatus(
                    context = context,
                    isPro = uiState.value.isPro,
                    sessionsBeforeLongBreak = uiState.value.sessionsBeforeLongBreak,
                    isLoggedIn = true,
                    metricsOptIn = optedIn,
                )
            }
        }
    }

    fun setMetricsOptIn(enabled: Boolean) {
        if (!uiState.value.isLoggedIn || _isUpdatingMetricsOptIn.value) return
        val previous = _metricsOptIn.value
        _metricsOptIn.value = enabled
        _metricsOptInError.value = null
        _isUpdatingMetricsOptIn.value = true

        viewModelScope.launch {
            userRepository.updateProfile(UpdateProfileRequest(metricsOptIn = enabled))
                .onSuccess {
                    val confirmed = userRepository.metricsOptIn.value
                    _metricsOptIn.value = confirmed
                    _isUpdatingMetricsOptIn.value = false
                    WearDataLayerHelper.pushUserStatus(
                        context = context,
                        isPro = uiState.value.isPro,
                        sessionsBeforeLongBreak = uiState.value.sessionsBeforeLongBreak,
                        isLoggedIn = true,
                        metricsOptIn = confirmed,
                    )
                }
                .onFailure {
                    _metricsOptIn.value = previous
                    _isUpdatingMetricsOptIn.value = false
                    _metricsOptInError.value = METRICS_OPT_IN_ERROR_MESSAGE
                }
        }
    }

    fun dismissMetricsOptInError() {
        _metricsOptInError.value = null
    }

    fun updatePomodoroMinutes(value: Int) = viewModelScope.launch {
        // Snap to nearest multiple of 5 and enforce minimum of 5
        val snapped = (Math.round(value / 5.0) * 5).toInt().coerceIn(5, 120)
        prefsRepo.updatePomodoroMinutes(snapped)
    }

    fun updateShortBreakMinutes(value: Int) = viewModelScope.launch {
        prefsRepo.updateShortBreakMinutes(value.coerceIn(1, 30))
    }

    fun updateLongBreakMinutes(value: Int) = viewModelScope.launch {
        // Snap to nearest multiple of 5 and enforce minimum of 5
        val snapped = (Math.round(value / 5.0) * 5).toInt().coerceIn(5, 60)
        prefsRepo.updateLongBreakMinutes(snapped)
    }

    fun updateSessionsBeforeLongBreak(value: Int) = viewModelScope.launch {
        prefsRepo.updateSessionsBeforeLongBreak(value.coerceIn(1, 12))
    }

    fun updateTimeBlockMinutes(value: Int) = viewModelScope.launch {
        // Snap to nearest multiple of 15 and enforce minimum of 15
        val snapped = (Math.round(value / 15.0) * 15).toInt().coerceIn(15, 480)
        prefsRepo.updateTimeBlockMinutes(snapped)
    }

    fun toggleAutoStartBreaks() = viewModelScope.launch {
        prefsRepo.updateAutoStartBreaks(!uiState.value.autoStartBreaks)
    }

    fun toggleAutoStartNextPomodoro() = viewModelScope.launch {
        prefsRepo.updateAutoStartNextPomodoro(!uiState.value.autoStartNextPomodoro)
    }

    fun toggleSound() = viewModelScope.launch {
        prefsRepo.updateSoundEnabled(!uiState.value.soundEnabled)
    }

    fun toggleVibration() = viewModelScope.launch {
        prefsRepo.updateVibrationEnabled(!uiState.value.vibrationEnabled)
    }

    fun setThemeMode(mode: ThemeMode) = viewModelScope.launch {
        prefsRepo.updateThemeMode(mode)
    }

    fun toggleDynamicColor() = viewModelScope.launch {
        prefsRepo.updateDynamicColor(!uiState.value.dynamicColor)
    }

    fun setSelectedTheme(themeId: String) {
        viewModelScope.launch {
            prefsRepo.updateSelectedTheme(themeId)
        }
    }

    fun updateFlowtimeMinMinutes(value: Int) = viewModelScope.launch {
        prefsRepo.updateFlowtimeMinMinutes(value.coerceIn(1, 30))
    }

    fun setDefaultMode(mode: FocusMode) = viewModelScope.launch {
        if (!mode.isFreeTier && uiState.value.subscriptionTier == SubscriptionTier.FREE) return@launch
        prefsRepo.updateDefaultMode(mode.name)
    }

    fun toggleKeepScreenOn() = viewModelScope.launch {
        prefsRepo.updateKeepScreenOn(!uiState.value.keepScreenOn)
    }

    fun toggleDailyReminder() = viewModelScope.launch {
        val newValue = !uiState.value.dailyReminderEnabled
        prefsRepo.updateDailyReminderEnabled(newValue)
        if (newValue) {
            scheduleDailyReminder(uiState.value.dailyReminderHour, uiState.value.dailyReminderMinute)
        } else {
            cancelDailyReminder()
        }
    }

    fun updateDailyReminderTime(hour: Int, minute: Int) = viewModelScope.launch {
        prefsRepo.updateDailyReminderHour(hour)
        prefsRepo.updateDailyReminderMinute(minute)
        if (uiState.value.dailyReminderEnabled) {
            scheduleDailyReminder(hour, minute)
        }
    }

    fun toggleMidpointCheckIn() = viewModelScope.launch {
        prefsRepo.updateMidpointCheckIn(!uiState.value.midpointCheckIn)
    }

    fun toggleTimerNotifications() = viewModelScope.launch {
        prefsRepo.updateTimerNotificationsEnabled(!uiState.value.timerNotificationsEnabled)
    }

    fun toggleCelebrateStreakRecords() = viewModelScope.launch {
        prefsRepo.updateCelebrateStreakRecords(!uiState.value.celebrateStreakRecords)
    }

    fun toggleWeeklyRecap() = viewModelScope.launch {
        val newValue = !uiState.value.weeklyRecapEnabled
        prefsRepo.updateWeeklyRecapEnabled(newValue)
        if (newValue) {
            val prefs = prefsRepo.preferences.first()
            WeeklyRecapScheduler.schedule(context, prefs.weeklyRecapDayOfWeek, prefs.weeklyRecapHour, prefs.weeklyRecapMinute)
        } else {
            WeeklyRecapScheduler.cancel(context)
        }
    }

    fun toggleShowJournalAfterSession() = viewModelScope.launch {
        prefsRepo.updateShowJournalAfterSession(!uiState.value.showJournalAfterSession)
    }

    fun toggleHapticTimerTick() = viewModelScope.launch {
        prefsRepo.updateHapticTimerTickEnabled(!uiState.value.hapticTimerTickEnabled)
    }

    private fun scheduleDailyReminder(hour: Int, minute: Int) {
        DailyReminderScheduler.schedule(context, hour, minute)
    }

    private fun cancelDailyReminder() {
        DailyReminderScheduler.cancel(context)
    }

    fun requestSync() {
        syncStatusManager.requestImmediateSync()
    }

    private fun UserPreferences.toUiState(
        currentStreak: Int = 0,
        isPro: Boolean = false,
        subscriptionTier: SubscriptionTier = SubscriptionTier.FREE,
        isOnline: Boolean = true,
        syncState: SyncState = SyncState.Idle,
        lastSyncAt: Long? = null,
        pendingChangesCount: Int = 0,
        isLoggedIn: Boolean = false,
        metricsOptIn: Boolean = false,
        isUpdatingMetricsOptIn: Boolean = false,
        metricsOptInError: String? = null,
    ) = SettingsUiState(
        pomodoroMinutes = pomodoroMinutes,
        shortBreakMinutes = shortBreakMinutes,
        longBreakMinutes = longBreakMinutes,
        sessionsBeforeLongBreak = sessionsBeforeLongBreak,
        timeBlockMinutes = timeBlockMinutes,
        autoStartBreaks = autoStartBreaks,
        autoStartNextPomodoro = autoStartNextPomodoro,
        soundEnabled = soundEnabled,
        vibrationEnabled = vibrationEnabled,
        themeMode = themeMode,
        dynamicColor = dynamicColor,
        flowtimeMinMinutes = flowtimeMinMinutes,
        defaultMode = FocusMode.entries.find { it.name == defaultMode } ?: FocusMode.Pomodoro,
        keepScreenOn = keepScreenOn,
        dailyReminderEnabled = dailyReminderEnabled,
        dailyReminderHour = dailyReminderHour,
        dailyReminderMinute = dailyReminderMinute,
        midpointCheckIn = midpointCheckIn,
        timerNotificationsEnabled = timerNotificationsEnabled,
        showJournalAfterSession = showJournalAfterSession,
        hapticTimerTickEnabled = hapticTimerTickEnabled,
        celebrateStreakRecords = celebrateStreakRecords,
        weeklyRecapEnabled = weeklyRecapEnabled,
        selectedTheme = selectedTheme,
        currentStreak = currentStreak,
        isPro = isPro,
        subscriptionTier = subscriptionTier,
        isOnline = isOnline,
        syncState = syncState,
        lastSyncAt = lastSyncAt,
        pendingChangesCount = pendingChangesCount,
        isLoggedIn = isLoggedIn,
        metricsOptIn = metricsOptIn,
        isUpdatingMetricsOptIn = isUpdatingMetricsOptIn,
        metricsOptInError = metricsOptInError,
    )
}
