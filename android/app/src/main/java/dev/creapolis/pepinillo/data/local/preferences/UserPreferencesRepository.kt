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
import dev.creapolis.pepinillo.data.local.dao.PreferenceSyncDao
import dev.creapolis.pepinillo.data.local.entity.PreferenceSyncEntity
import dev.creapolis.pepinillo.ui.theme.ThemeMode
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map
import java.util.TimeZone
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
    // Persisted "home" timezone for day-key computations. Captured once on first run and
    // then frozen so that traveling across timezones does not shift the user's day boundary
    // (see W-4: SessionRepository.startOfDay + SyncEngine day-key computations).
    val userTimezone: String = TimeZone.getDefault().id,
)

private val Context.dataStore: DataStore<Preferences> by preferencesDataStore(name = "user_preferences")

@Singleton
class UserPreferencesRepository @Inject constructor(
    private val context: Context,
    private val preferenceSyncDao: PreferenceSyncDao,
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
        val USER_TIMEZONE = stringPreferencesKey("user_timezone")
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
            userTimezone = prefs[Keys.USER_TIMEZONE] ?: TimeZone.getDefault().id,
        )
    }

    /**
     * Returns the persisted home timezone id, initializing it from the device's current
     * timezone on first access so it stays stable thereafter (W-4). Used by day-key
     * computations in [dev.creapolis.pepinillo.data.repository.SessionRepository] and
     * [dev.creapolis.pepinillo.data.sync.SyncEngine].
     */
    suspend fun getOrInitUserTimezone(): String {
        val stored = context.dataStore.data.first()[Keys.USER_TIMEZONE]
        if (!stored.isNullOrEmpty()) return stored
        val systemTz = TimeZone.getDefault().id
        context.dataStore.edit { it[Keys.USER_TIMEZONE] = systemTz }
        return systemTz
    }

    // ── Syncable preference updaters (mark dirty for sync) ──

    suspend fun updatePomodoroMinutes(value: Int) = updateAndMarkDirty("pomodoro_minutes") { it[Keys.POMODORO_MINUTES] = value }
    suspend fun updateShortBreakMinutes(value: Int) = updateAndMarkDirty("short_break_minutes") { it[Keys.SHORT_BREAK_MINUTES] = value }
    suspend fun updateLongBreakMinutes(value: Int) = updateAndMarkDirty("long_break_minutes") { it[Keys.LONG_BREAK_MINUTES] = value }
    suspend fun updateSessionsBeforeLongBreak(value: Int) = updateAndMarkDirty("sessions_before_long_break") { it[Keys.SESSIONS_BEFORE_LONG_BREAK] = value }
    suspend fun updateTimeBlockMinutes(value: Int) = updateAndMarkDirty("time_block_minutes") { it[Keys.TIME_BLOCK_MINUTES] = value }
    suspend fun updateAutoStartBreaks(value: Boolean) = updateAndMarkDirty("auto_start_breaks") { it[Keys.AUTO_START_BREAKS] = value }
    suspend fun updateAutoStartNextPomodoro(value: Boolean) = updateAndMarkDirty("auto_start_next_pomodoro") { it[Keys.AUTO_START_NEXT_POMODORO] = value }
    suspend fun updateSoundEnabled(value: Boolean) = updateAndMarkDirty("sound_enabled") { it[Keys.SOUND_ENABLED] = value }
    suspend fun updateVibrationEnabled(value: Boolean) = updateAndMarkDirty("vibration_enabled") { it[Keys.VIBRATION_ENABLED] = value }
    suspend fun updateThemeMode(mode: ThemeMode) = updateAndMarkDirty("theme_mode") { it[Keys.THEME_MODE] = mode.name }
    suspend fun updateDynamicColor(value: Boolean) = updateAndMarkDirty("dynamic_color") { it[Keys.DYNAMIC_COLOR] = value }
    suspend fun updateSelectedTheme(value: String) = updateAndMarkDirty("selected_theme") { it[Keys.SELECTED_THEME] = value }
    suspend fun updateFlowtimeMinMinutes(value: Int) = updateAndMarkDirty("flowtime_min_minutes") { it[Keys.FLOWTIME_MIN_MINUTES] = value }
    suspend fun updateDefaultMode(value: String) = updateAndMarkDirty("default_mode") { it[Keys.DEFAULT_MODE] = value }
    suspend fun updateKeepScreenOn(value: Boolean) = updateAndMarkDirty("keep_screen_on") { it[Keys.KEEP_SCREEN_ON] = value }
    suspend fun updateMidpointCheckIn(value: Boolean) = updateAndMarkDirty("midpoint_check_in") { it[Keys.MIDPOINT_CHECK_IN] = value }
    suspend fun updateShowJournalAfterSession(value: Boolean) = updateAndMarkDirty("show_journal_after_session") { it[Keys.SHOW_JOURNAL_AFTER_SESSION] = value }

    // ── Device-specific preference updaters (NOT synced) ──

    suspend fun completeOnboarding() = update {
        it[Keys.ONBOARDING_COMPLETED] = true
        it[Keys.ONBOARDING_PAGE] = 0
    }
    suspend fun updateOnboardingPage(page: Int) = update { it[Keys.ONBOARDING_PAGE] = page }
    suspend fun updateDailyReminderEnabled(value: Boolean) = update { it[Keys.DAILY_REMINDER_ENABLED] = value }
    suspend fun updateDailyReminderHour(value: Int) = update { it[Keys.DAILY_REMINDER_HOUR] = value }
    suspend fun updateDailyReminderMinute(value: Int) = update { it[Keys.DAILY_REMINDER_MINUTE] = value }
    suspend fun updateTimerNotificationsEnabled(value: Boolean) = update { it[Keys.TIMER_NOTIFICATIONS_ENABLED] = value }

    // ── Helpers ──

    private suspend fun updateAndMarkDirty(syncKey: String, block: (MutablePreferences) -> Unit) {
        context.dataStore.edit { prefs -> block(prefs) }
        preferenceSyncDao.upsert(
            PreferenceSyncEntity(
                key = syncKey,
                updatedAt = System.currentTimeMillis(),
                isDirty = true,
            )
        )
    }

    private suspend fun update(block: (MutablePreferences) -> Unit) {
        context.dataStore.edit { prefs -> block(prefs) }
    }
}
