package dev.creapolis.pepinillo.feature.settings

import android.content.Context
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import dagger.hilt.android.lifecycle.HiltViewModel
import dagger.hilt.android.qualifiers.ApplicationContext
import dev.creapolis.pepinillo.BuildConfig
import dev.creapolis.pepinillo.core.billing.FeatureGate
import dev.creapolis.pepinillo.core.billing.SubscriptionTier
import dev.creapolis.pepinillo.core.auth.AuthStore
import dev.creapolis.pepinillo.core.billing.SubscriptionState
import dev.creapolis.pepinillo.data.local.entity.DailyStatsEntity
import dev.creapolis.pepinillo.domain.streak.StreakProtectionService
import dev.creapolis.pepinillo.data.local.preferences.UserPreferences
import dev.creapolis.pepinillo.data.local.preferences.UserPreferencesRepository
import dev.creapolis.pepinillo.data.repository.SessionRepository
import dev.creapolis.pepinillo.data.sync.SyncState
import dev.creapolis.pepinillo.data.sync.SyncStatusManager
import dev.creapolis.pepinillo.feature.focus.FocusMode
import dev.creapolis.pepinillo.service.DailyReminderWorker
import dev.creapolis.pepinillo.ui.theme.AppTheme
import dev.creapolis.pepinillo.ui.theme.ThemeController
import dev.creapolis.pepinillo.ui.theme.ThemeMode
import dev.creapolis.pepinillo.wear.WearDataLayerHelper
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import java.util.Calendar
import java.util.concurrent.TimeUnit
import javax.inject.Inject

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
    val selectedTheme: String = "materialYou",
    val currentStreak: Int = 0,
    val isPro: Boolean = false,
    val subscriptionTier: SubscriptionTier = SubscriptionTier.FREE,
    // Sync status
    val isOnline: Boolean = true,
    val syncState: SyncState = SyncState.Idle,
    val lastSyncAt: Long? = null,
    val pendingChangesCount: Int = 0,
    val isLoggedIn: Boolean = false,
)

@HiltViewModel
class SettingsViewModel @Inject constructor(
    @ApplicationContext private val context: Context,
    private val prefsRepo: UserPreferencesRepository,
    private val sessionRepository: SessionRepository,
    private val featureGate: FeatureGate,
    private val syncStatusManager: SyncStatusManager,
    private val authStore: AuthStore,
) : ViewModel() {

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
        )
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), SettingsUiState())

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
    }

    fun updatePomodoroMinutes(value: Int) = viewModelScope.launch {
        prefsRepo.updatePomodoroMinutes(value.coerceIn(1, 120))
    }

    fun updateShortBreakMinutes(value: Int) = viewModelScope.launch {
        prefsRepo.updateShortBreakMinutes(value.coerceIn(1, 30))
    }

    fun updateLongBreakMinutes(value: Int) = viewModelScope.launch {
        prefsRepo.updateLongBreakMinutes(value.coerceIn(5, 60))
    }

    fun updateSessionsBeforeLongBreak(value: Int) = viewModelScope.launch {
        prefsRepo.updateSessionsBeforeLongBreak(value.coerceIn(1, 12))
    }

    fun updateTimeBlockMinutes(value: Int) = viewModelScope.launch {
        prefsRepo.updateTimeBlockMinutes(value.coerceIn(5, 480))
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

    fun toggleShowJournalAfterSession() = viewModelScope.launch {
        prefsRepo.updateShowJournalAfterSession(!uiState.value.showJournalAfterSession)
    }

    private fun scheduleDailyReminder(hour: Int, minute: Int) {
        val now = Calendar.getInstance()
        val target = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, hour)
            set(Calendar.MINUTE, minute)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
            if (before(now)) add(Calendar.DAY_OF_YEAR, 1)
        }
        val initialDelay = target.timeInMillis - now.timeInMillis

        val request = PeriodicWorkRequestBuilder<DailyReminderWorker>(24, TimeUnit.HOURS)
            .setInitialDelay(initialDelay, TimeUnit.MILLISECONDS)
            .build()

        WorkManager.getInstance(context)
            .enqueueUniquePeriodicWork("daily_reminder", ExistingPeriodicWorkPolicy.REPLACE, request)
    }

    private fun cancelDailyReminder() {
        WorkManager.getInstance(context).cancelUniqueWork("daily_reminder")
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
        selectedTheme = selectedTheme,
        currentStreak = currentStreak,
        isPro = isPro,
        subscriptionTier = subscriptionTier,
        isOnline = isOnline,
        syncState = syncState,
        lastSyncAt = lastSyncAt,
        pendingChangesCount = pendingChangesCount,
        isLoggedIn = isLoggedIn,
    )
}
