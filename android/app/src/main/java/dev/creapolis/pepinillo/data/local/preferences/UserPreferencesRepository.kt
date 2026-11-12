package dev.creapolis.pepinillo.data.local.preferences

import android.content.Context
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.intPreferencesKey
import androidx.datastore.preferences.core.longPreferencesKey
import androidx.datastore.preferences.core.MutablePreferences
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import dev.creapolis.pepinillo.data.local.dao.PreferenceSyncDao
import dev.creapolis.pepinillo.data.local.entity.PreferenceSyncEntity
import dev.creapolis.pepinillo.ui.theme.ThemeMode
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import java.util.Calendar
import javax.inject.Inject
import javax.inject.Singleton

import androidx.datastore.preferences.core.floatPreferencesKey

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
    val selectedSoundscape: String? = null,
    val soundscapeVolume: Float = 0.5f,
    /**
     * Opt-in micro-vibration every ~60s while a focus session is running.
     * Gated additionally by [vibrationEnabled] (the master toggle). Defaults off.
     * Device-local preference — not synced across devices.
     */
    val hapticTimerTickEnabled: Boolean = false,
    /**
     * Whether the Google Play in-app review prompt has already been requested.
     * Once true, the app will NEVER ask the user again.
     */
    val hasPromptedForReview: Boolean = false,
    /**
     * Completed focus sessions on this device, used to trigger the one-time review prompt.
     */
    val completedSessionsCount: Int = 0,
    /**
     * Whether completing a session that beats the all-time best streak shows a quiet
     * in-sheet celebration. Device-local preference — not synced across devices.
     */
    val celebrateStreakRecords: Boolean = true,
    /**
     * Last celebrated streak-record value (anti-repeat latch). The celebration fires only
     * when the current streak exceeds max(previousBest, this). Device-local.
     */
    val streakRecordCelebrated: Int = 0,
    /** Opt-in weekly focus summary notification. Device-local. */
    val weeklyRecapEnabled: Boolean = false,
    /** java.util.Calendar day-of-week constant (1-based, [Calendar.SUNDAY]=1). */
    val weeklyRecapDayOfWeek: Int = Calendar.SUNDAY,
    val weeklyRecapHour: Int = 18,
    val weeklyRecapMinute: Int = 0,
    /** Last weekly-recap dispatch (epoch millis); guards against WorkManager retries. */
    val weeklyRecapLastSentAt: Long = 0,
)

private val Context.dataStore: DataStore<Preferences> by preferencesDataStore(name = "user_preferences")

@Singleton
class UserPreferencesRepository @Inject constructor(
    private val context: Context,
    private val preferenceSyncDao: PreferenceSyncDao,
    private val dataStore: DataStore<Preferences> = context.dataStore,
) {
    private val mutex = Mutex()

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
        val SELECTED_SOUNDSCAPE = stringPreferencesKey("selected_soundscape")
        val SOUNDSCAPE_VOLUME = floatPreferencesKey("soundscape_volume")
        val HAPTIC_TIMER_TICK_ENABLED = booleanPreferencesKey("haptic_timer_tick_enabled")
        val HAS_PROMPTED_FOR_REVIEW = booleanPreferencesKey("has_prompted_for_review")
        val COMPLETED_SESSIONS_COUNT = intPreferencesKey("completed_sessions_count")
        val CELEBRATE_STREAK_RECORDS = booleanPreferencesKey("celebrate_streak_records")
        val STREAK_RECORD_CELEBRATED = intPreferencesKey("streak_record_celebrated")
        val WEEKLY_RECAP_ENABLED = booleanPreferencesKey("weekly_recap_enabled")
        val WEEKLY_RECAP_DAY_OF_WEEK = intPreferencesKey("weekly_recap_day_of_week")
        val WEEKLY_RECAP_HOUR = intPreferencesKey("weekly_recap_hour")
        val WEEKLY_RECAP_MINUTE = intPreferencesKey("weekly_recap_minute")
        val WEEKLY_RECAP_LAST_SENT_AT = longPreferencesKey("weekly_recap_last_sent_at")
    }

    val preferences: Flow<UserPreferences> = dataStore.data.map { prefs ->
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
            selectedSoundscape = prefs[Keys.SELECTED_SOUNDSCAPE],
            soundscapeVolume = prefs[Keys.SOUNDSCAPE_VOLUME] ?: 0.5f,
            hapticTimerTickEnabled = prefs[Keys.HAPTIC_TIMER_TICK_ENABLED] ?: false,
            hasPromptedForReview = prefs[Keys.HAS_PROMPTED_FOR_REVIEW] ?: false,
            completedSessionsCount = prefs[Keys.COMPLETED_SESSIONS_COUNT] ?: 0,
            celebrateStreakRecords = prefs[Keys.CELEBRATE_STREAK_RECORDS] ?: true,
            streakRecordCelebrated = prefs[Keys.STREAK_RECORD_CELEBRATED] ?: 0,
            weeklyRecapEnabled = prefs[Keys.WEEKLY_RECAP_ENABLED] ?: false,
            weeklyRecapDayOfWeek = prefs[Keys.WEEKLY_RECAP_DAY_OF_WEEK] ?: Calendar.SUNDAY,
            weeklyRecapHour = prefs[Keys.WEEKLY_RECAP_HOUR] ?: 18,
            weeklyRecapMinute = prefs[Keys.WEEKLY_RECAP_MINUTE] ?: 0,
            weeklyRecapLastSentAt = prefs[Keys.WEEKLY_RECAP_LAST_SENT_AT] ?: 0L,
        )
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
    suspend fun updateSelectedSoundscape(name: String?) = update {
        if (name != null) it[Keys.SELECTED_SOUNDSCAPE] = name else it.remove(Keys.SELECTED_SOUNDSCAPE)
    }
    suspend fun updateSoundscapeVolume(volume: Float) = update { it[Keys.SOUNDSCAPE_VOLUME] = volume }
    suspend fun updateHapticTimerTickEnabled(value: Boolean) = update { it[Keys.HAPTIC_TIMER_TICK_ENABLED] = value }
    suspend fun markReviewPrompted() = update { it[Keys.HAS_PROMPTED_FOR_REVIEW] = true }
    suspend fun updateCelebrateStreakRecords(value: Boolean) = update { it[Keys.CELEBRATE_STREAK_RECORDS] = value }
    suspend fun updateStreakRecordCelebrated(value: Int) = update { it[Keys.STREAK_RECORD_CELEBRATED] = value }
    suspend fun updateWeeklyRecapEnabled(value: Boolean) = update { it[Keys.WEEKLY_RECAP_ENABLED] = value }
    suspend fun updateWeeklyRecapDayOfWeek(value: Int) = update { it[Keys.WEEKLY_RECAP_DAY_OF_WEEK] = value }
    suspend fun updateWeeklyRecapHour(value: Int) = update { it[Keys.WEEKLY_RECAP_HOUR] = value }
    suspend fun updateWeeklyRecapMinute(value: Int) = update { it[Keys.WEEKLY_RECAP_MINUTE] = value }
    suspend fun updateWeeklyRecapLastSentAt(value: Long) = update { it[Keys.WEEKLY_RECAP_LAST_SENT_AT] = value }
    suspend fun incrementCompletedSessionsCount(): Int {
        var count = 0
        update {
            val cur = it[Keys.COMPLETED_SESSIONS_COUNT] ?: 0
            count = cur + 1
            it[Keys.COMPLETED_SESSIONS_COUNT] = count
        }
        return count
    }

    // ── Sync applying helper (clean update from server) ──

    /**
     * Applies a preference value received from remote sync directly to DataStore
     * and sets [PreferenceSyncEntity.isDirty] = false with the given [updatedAt]
     * timestamp atomically under [mutex].
     */
    suspend fun updateFromSync(syncKey: String, value: String, updatedAt: Long) = mutex.withLock {
        val wrote = writeDataStoreValueOnly(syncKey, value)
        if (wrote) {
            preferenceSyncDao.upsert(
                PreferenceSyncEntity(
                    key = syncKey,
                    updatedAt = updatedAt,
                    isDirty = false,
                )
            )
        }
    }

    private suspend fun writeDataStoreValueOnly(key: String, value: String): Boolean {
        var success = true
        dataStore.edit { prefs ->
            when (key) {
                "pomodoro_minutes" -> value.toIntOrNull()?.let { prefs[Keys.POMODORO_MINUTES] = it } ?: run { success = false }
                "short_break_minutes" -> value.toIntOrNull()?.let { prefs[Keys.SHORT_BREAK_MINUTES] = it } ?: run { success = false }
                "long_break_minutes" -> value.toIntOrNull()?.let { prefs[Keys.LONG_BREAK_MINUTES] = it } ?: run { success = false }
                "sessions_before_long_break" -> value.toIntOrNull()?.let { prefs[Keys.SESSIONS_BEFORE_LONG_BREAK] = it } ?: run { success = false }
                "time_block_minutes" -> value.toIntOrNull()?.let { prefs[Keys.TIME_BLOCK_MINUTES] = it } ?: run { success = false }
                "auto_start_breaks" -> value.toBooleanStrictOrNull()?.let { prefs[Keys.AUTO_START_BREAKS] = it } ?: run { success = false }
                "auto_start_next_pomodoro" -> value.toBooleanStrictOrNull()?.let { prefs[Keys.AUTO_START_NEXT_POMODORO] = it } ?: run { success = false }
                "sound_enabled" -> value.toBooleanStrictOrNull()?.let { prefs[Keys.SOUND_ENABLED] = it } ?: run { success = false }
                "vibration_enabled" -> value.toBooleanStrictOrNull()?.let { prefs[Keys.VIBRATION_ENABLED] = it } ?: run { success = false }
                "theme_mode" -> {
                    try {
                        val mode = ThemeMode.valueOf(value)
                        prefs[Keys.THEME_MODE] = mode.name
                    } catch (_: IllegalArgumentException) {
                        success = false
                    }
                }
                "dynamic_color" -> value.toBooleanStrictOrNull()?.let { prefs[Keys.DYNAMIC_COLOR] = it } ?: run { success = false }
                "selected_theme" -> prefs[Keys.SELECTED_THEME] = value
                "keep_screen_on" -> value.toBooleanStrictOrNull()?.let { prefs[Keys.KEEP_SCREEN_ON] = it } ?: run { success = false }
                "default_mode" -> prefs[Keys.DEFAULT_MODE] = value
                "show_journal_after_session" -> value.toBooleanStrictOrNull()?.let { prefs[Keys.SHOW_JOURNAL_AFTER_SESSION] = it } ?: run { success = false }
                "flowtime_min_minutes" -> value.toIntOrNull()?.let { prefs[Keys.FLOWTIME_MIN_MINUTES] = it } ?: run { success = false }
                "midpoint_check_in" -> value.toBooleanStrictOrNull()?.let { prefs[Keys.MIDPOINT_CHECK_IN] = it } ?: run { success = false }
                else -> success = false
            }
        }
        return success
    }

    // ── Helpers ──

    private suspend fun updateAndMarkDirty(syncKey: String, block: (MutablePreferences) -> Unit) = mutex.withLock {
        val now = System.currentTimeMillis()
        dataStore.edit { prefs -> block(prefs) }
        preferenceSyncDao.upsert(
            PreferenceSyncEntity(
                key = syncKey,
                updatedAt = now,
                isDirty = true,
            )
        )
    }

    private suspend fun update(block: (MutablePreferences) -> Unit) = mutex.withLock {
        dataStore.edit { prefs -> block(prefs) }
    }
}
