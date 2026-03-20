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
    val selectedTheme: String = "materialYou",
    val onboardingCompleted: Boolean = false,
    val onboardingPage: Int = 0,
    val flowtimeMinMinutes: Int = 5,
    val defaultMode: String = "Pomodoro",
    val keepScreenOn: Boolean = false,
    val dailyReminderEnabled: Boolean = false,
    val dailyReminderHour: Int = 9,
    val dailyReminderMinute: Int = 0,
    val midpointCheckIn: Boolean = false,
    val timerNotificationsEnabled: Boolean = true,
    val showJournalAfterSession: Boolean = true,
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
        val SELECTED_THEME = stringPreferencesKey("selected_theme")
        val ONBOARDING_COMPLETED = booleanPreferencesKey("onboarding_completed")
        val ONBOARDING_PAGE = intPreferencesKey("onboarding_page")
        val FLOWTIME_MIN_MINUTES = intPreferencesKey("flowtime_min_minutes")
        val DEFAULT_MODE = stringPreferencesKey("default_mode")
        val KEEP_SCREEN_ON = booleanPreferencesKey("keep_screen_on")
        val DAILY_REMINDER_ENABLED = booleanPreferencesKey("daily_reminder_enabled")
        val DAILY_REMINDER_HOUR = intPreferencesKey("daily_reminder_hour")
        val DAILY_REMINDER_MINUTE = intPreferencesKey("daily_reminder_minute")
        val MIDPOINT_CHECK_IN = booleanPreferencesKey("midpoint_check_in")
        val TIMER_NOTIFICATIONS_ENABLED = booleanPreferencesKey("timer_notifications_enabled")
        val SHOW_JOURNAL_AFTER_SESSION = booleanPreferencesKey("show_journal_after_session")
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
            selectedTheme = prefs[Keys.SELECTED_THEME] ?: "materialYou",
            onboardingCompleted = prefs[Keys.ONBOARDING_COMPLETED] ?: false,
            onboardingPage = prefs[Keys.ONBOARDING_PAGE] ?: 0,
            flowtimeMinMinutes = prefs[Keys.FLOWTIME_MIN_MINUTES] ?: 5,
            defaultMode = prefs[Keys.DEFAULT_MODE] ?: "Pomodoro",
            keepScreenOn = prefs[Keys.KEEP_SCREEN_ON] ?: false,
            dailyReminderEnabled = prefs[Keys.DAILY_REMINDER_ENABLED] ?: false,
            dailyReminderHour = prefs[Keys.DAILY_REMINDER_HOUR] ?: 9,
            dailyReminderMinute = prefs[Keys.DAILY_REMINDER_MINUTE] ?: 0,
            midpointCheckIn = prefs[Keys.MIDPOINT_CHECK_IN] ?: false,
            timerNotificationsEnabled = prefs[Keys.TIMER_NOTIFICATIONS_ENABLED] ?: true,
            showJournalAfterSession = prefs[Keys.SHOW_JOURNAL_AFTER_SESSION] ?: true,
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
    suspend fun updateSelectedTheme(value: String) = update { it[Keys.SELECTED_THEME] = value }
    suspend fun completeOnboarding() = update {
        it[Keys.ONBOARDING_COMPLETED] = true
        it[Keys.ONBOARDING_PAGE] = 0
    }
    suspend fun updateOnboardingPage(page: Int) = update { it[Keys.ONBOARDING_PAGE] = page }
    suspend fun updateFlowtimeMinMinutes(value: Int) = update { it[Keys.FLOWTIME_MIN_MINUTES] = value }
    suspend fun updateDefaultMode(value: String) = update { it[Keys.DEFAULT_MODE] = value }
    suspend fun updateKeepScreenOn(value: Boolean) = update { it[Keys.KEEP_SCREEN_ON] = value }
    suspend fun updateDailyReminderEnabled(value: Boolean) = update { it[Keys.DAILY_REMINDER_ENABLED] = value }
    suspend fun updateDailyReminderHour(value: Int) = update { it[Keys.DAILY_REMINDER_HOUR] = value }
    suspend fun updateDailyReminderMinute(value: Int) = update { it[Keys.DAILY_REMINDER_MINUTE] = value }
    suspend fun updateMidpointCheckIn(value: Boolean) = update { it[Keys.MIDPOINT_CHECK_IN] = value }
    suspend fun updateTimerNotificationsEnabled(value: Boolean) = update { it[Keys.TIMER_NOTIFICATIONS_ENABLED] = value }
    suspend fun updateShowJournalAfterSession(value: Boolean) = update { it[Keys.SHOW_JOURNAL_AFTER_SESSION] = value }

    private suspend fun update(block: (MutablePreferences) -> Unit) {
        context.dataStore.edit { prefs -> block(prefs) }
    }
}
