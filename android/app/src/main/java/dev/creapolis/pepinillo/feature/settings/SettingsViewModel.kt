package dev.creapolis.pepinillo.feature.settings

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import dagger.hilt.android.lifecycle.HiltViewModel
import dev.creapolis.pepinillo.data.local.preferences.UserPreferences
import dev.creapolis.pepinillo.data.local.preferences.UserPreferencesRepository
import dev.creapolis.pepinillo.ui.theme.ThemeController
import dev.creapolis.pepinillo.ui.theme.ThemeMode
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
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
    val appVersion: String = "1.0.0",
)

@HiltViewModel
class SettingsViewModel @Inject constructor(
    private val prefsRepo: UserPreferencesRepository,
) : ViewModel() {

    val uiState: StateFlow<SettingsUiState> = prefsRepo.preferences
        .map { it.toUiState() }
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), SettingsUiState())

    init {
        // Sync theme controller with persisted preferences
        viewModelScope.launch {
            prefsRepo.preferences.collect { prefs ->
                ThemeController.setThemeMode(prefs.themeMode)
                ThemeController.setDynamicColor(prefs.dynamicColor)
            }
        }
    }

    fun updatePomodoroMinutes(value: Int) = viewModelScope.launch {
        prefsRepo.updatePomodoroMinutes(value.coerceIn(1, 90))
    }

    fun updateShortBreakMinutes(value: Int) = viewModelScope.launch {
        prefsRepo.updateShortBreakMinutes(value.coerceIn(1, 30))
    }

    fun updateLongBreakMinutes(value: Int) = viewModelScope.launch {
        prefsRepo.updateLongBreakMinutes(value.coerceIn(1, 60))
    }

    fun updateSessionsBeforeLongBreak(value: Int) = viewModelScope.launch {
        prefsRepo.updateSessionsBeforeLongBreak(value.coerceIn(1, 10))
    }

    fun updateTimeBlockMinutes(value: Int) = viewModelScope.launch {
        prefsRepo.updateTimeBlockMinutes(value.coerceIn(10, 180))
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

    private fun UserPreferences.toUiState() = SettingsUiState(
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
    )
}
