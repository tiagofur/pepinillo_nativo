package dev.creapolis.pepinillo.data.local.preferences

import android.content.Context
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.intPreferencesKey
import androidx.datastore.preferences.core.MutablePreferences
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import dev.creapolis.pepinillo.ui.theme.ThemeMode
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import javax.inject.Inject
import javax.inject.Singleton

data class UserPreferences(
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
)

private val Context.dataStore: DataStore<Preferences> by preferencesDataStore(name = "user_preferences")

@Singleton
class UserPreferencesRepository @Inject constructor(
    private val context: Context,
) {
    private object Keys {
        val POMODORO_MINUTES = intPreferencesKey("pomodoro_minutes")
        val SHORT_BREAK_MINUTES = intPreferencesKey("short_break_minutes")
        val LONG_BREAK_MINUTES = intPreferencesKey("long_break_minutes")
        val SESSIONS_BEFORE_LONG_BREAK = intPreferencesKey("sessions_before_long_break")
        val TIME_BLOCK_MINUTES = intPreferencesKey("time_block_minutes")
        val AUTO_START_BREAKS = booleanPreferencesKey("auto_start_breaks")
        val AUTO_START_NEXT_POMODORO = booleanPreferencesKey("auto_start_next_pomodoro")
        val SOUND_ENABLED = booleanPreferencesKey("sound_enabled")
        val VIBRATION_ENABLED = booleanPreferencesKey("vibration_enabled")
        val THEME_MODE = stringPreferencesKey("theme_mode")
        val DYNAMIC_COLOR = booleanPreferencesKey("dynamic_color")
    }

    val preferences: Flow<UserPreferences> = context.dataStore.data.map { prefs ->
        UserPreferences(
            pomodoroMinutes = prefs[Keys.POMODORO_MINUTES] ?: 25,
            shortBreakMinutes = prefs[Keys.SHORT_BREAK_MINUTES] ?: 5,
            longBreakMinutes = prefs[Keys.LONG_BREAK_MINUTES] ?: 15,
            sessionsBeforeLongBreak = prefs[Keys.SESSIONS_BEFORE_LONG_BREAK] ?: 4,
            timeBlockMinutes = prefs[Keys.TIME_BLOCK_MINUTES] ?: 60,
            autoStartBreaks = prefs[Keys.AUTO_START_BREAKS] ?: true,
            autoStartNextPomodoro = prefs[Keys.AUTO_START_NEXT_POMODORO] ?: false,
            soundEnabled = prefs[Keys.SOUND_ENABLED] ?: true,
            vibrationEnabled = prefs[Keys.VIBRATION_ENABLED] ?: true,
            themeMode = prefs[Keys.THEME_MODE]?.let { ThemeMode.valueOf(it) } ?: ThemeMode.System,
            dynamicColor = prefs[Keys.DYNAMIC_COLOR] ?: true,
        )
    }

    suspend fun updatePomodoroMinutes(value: Int) = update { it[Keys.POMODORO_MINUTES] = value }
    suspend fun updateShortBreakMinutes(value: Int) = update { it[Keys.SHORT_BREAK_MINUTES] = value }
    suspend fun updateLongBreakMinutes(value: Int) = update { it[Keys.LONG_BREAK_MINUTES] = value }
    suspend fun updateSessionsBeforeLongBreak(value: Int) = update { it[Keys.SESSIONS_BEFORE_LONG_BREAK] = value }
    suspend fun updateTimeBlockMinutes(value: Int) = update { it[Keys.TIME_BLOCK_MINUTES] = value }
    suspend fun updateAutoStartBreaks(value: Boolean) = update { it[Keys.AUTO_START_BREAKS] = value }
    suspend fun updateAutoStartNextPomodoro(value: Boolean) = update { it[Keys.AUTO_START_NEXT_POMODORO] = value }
    suspend fun updateSoundEnabled(value: Boolean) = update { it[Keys.SOUND_ENABLED] = value }
    suspend fun updateVibrationEnabled(value: Boolean) = update { it[Keys.VIBRATION_ENABLED] = value }
    suspend fun updateThemeMode(mode: ThemeMode) = update { it[Keys.THEME_MODE] = mode.name }
    suspend fun updateDynamicColor(value: Boolean) = update { it[Keys.DYNAMIC_COLOR] = value }

    private suspend fun update(block: (MutablePreferences) -> Unit) {
        context.dataStore.edit { prefs -> block(prefs) }
    }
}
