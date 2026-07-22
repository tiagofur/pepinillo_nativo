package dev.creapolis.pepinillo.data.sync

import android.util.Log
import dev.creapolis.pepinillo.core.network.NetworkResult
import dev.creapolis.pepinillo.core.network.PepinilloApiClient
import dev.creapolis.pepinillo.core.network.PreferenceSyncItem
import dev.creapolis.pepinillo.core.network.PreferenceSyncRequest
import dev.creapolis.pepinillo.data.local.dao.PreferenceSyncDao
import dev.creapolis.pepinillo.data.local.entity.PreferenceSyncEntity
import dev.creapolis.pepinillo.data.local.preferences.UserPreferencesRepository
import kotlinx.coroutines.flow.first
import java.time.Instant
import java.time.ZoneOffset
import java.time.format.DateTimeFormatter
import javax.inject.Inject
import javax.inject.Singleton

private const val TAG = "SettingsSyncEngine"

@Singleton
class SettingsSyncEngine @Inject constructor(
    private val preferenceSyncDao: PreferenceSyncDao,
    private val userPreferencesRepository: UserPreferencesRepository,
    private val apiClient: PepinilloApiClient,
    private val syncLock: SyncLock,
) {
    // Preference keys that should sync (exclude device-specific ones)
    private val syncableKeys = setOf(
        "pomodoro_minutes", "short_break_minutes", "long_break_minutes",
        "time_block_minutes", "auto_start_breaks", "auto_start_next_pomodoro",
        "sessions_before_long_break", "sound_enabled", "vibration_enabled",
        "theme_mode", "dynamic_color", "selected_theme", "keep_screen_on",
        "default_mode", "show_journal_after_session",
        "flowtime_min_minutes", "midpoint_check_in",
    )

    // Device-specific keys that should NOT sync:
    // onboarding_completed, onboarding_page, timer_notifications_enabled,
    // daily_reminder_enabled, daily_reminder_hour, daily_reminder_minute

    suspend fun syncSettings(): Result<Unit> = syncLock.withLock { syncSettingsImpl() }

    /** Unlocked body; [SyncEngine.syncAllImpl] calls this while already holding [SyncLock]. */
    internal suspend fun syncSettingsImpl(): Result<Unit> = runCatching {
        // 1. Get dirty preferences from PreferenceSyncDao
        val dirtyPrefs = preferenceSyncDao.getDirtyPreferences()
        if (dirtyPrefs.isEmpty()) {
            Log.d(TAG, "No dirty preferences, pulling from server")
            pullServerPreferences()
            return@runCatching
        }

        val pushedTimestamps = dirtyPrefs.associate { it.key to it.updatedAt }

        // 2. Read current values from UserPreferencesRepository
        val currentPrefs = userPreferencesRepository.preferences.first()
        val items = dirtyPrefs
            .filter { it.key in syncableKeys }
            .mapNotNull { entity ->
                val value = readPreferenceValue(entity.key, currentPrefs) ?: return@mapNotNull null
                PreferenceSyncItem(
                    key = entity.key,
                    value = value,
                    updatedAt = entity.updatedAt.toRfc3339(),
                )
            }

        if (items.isEmpty()) {
            Log.d(TAG, "No syncable dirty preferences, marking dirty entities synced if unchanged")
            for (entity in dirtyPrefs) {
                preferenceSyncDao.markSyncedIfUnchanged(entity.key, entity.updatedAt)
            }
            return@runCatching
        }

        // 3. Build request and PUT /preferences
        val request = PreferenceSyncRequest(preferences = items)
        Log.d(TAG, "Pushing ${items.size} dirty preferences to server")

        when (val result = apiClient.upsertPreferences(request)) {
            is NetworkResult.Success -> {
                val response = result.data
                Log.d(TAG, "Server returned ${response.preferences.size} preferences")
                // 4. Apply server response (for keys where server is newer)
                applyServerPreferences(response.preferences)
                // 5. Mark pushed preferences synced if unchanged during network call
                for (item in items) {
                    val maxTimestamp = pushedTimestamps[item.key] ?: continue
                    preferenceSyncDao.markSyncedIfUnchanged(item.key, maxTimestamp)
                }
            }
            is NetworkResult.Error -> {
                Log.e(TAG, "Preferences sync error: ${result.code} ${result.message}")
                if (result.code == 401) throw AuthenticationException("syncSettings: 401 Unauthorized")
                throw SyncException("syncSettings failed: ${result.code} ${result.message}")
            }
            is NetworkResult.NetworkError -> throw result.exception
        }
    }

    suspend fun applyServerPreferences(prefs: List<PreferenceSyncItem>) {
        for (item in prefs) {
            if (item.key !in syncableKeys) continue

            val local = preferenceSyncDao.getByKey(item.key)
            val serverUpdatedAt = parseRfc3339(
                dateString = item.updatedAt,
                fallback = if (local != null && !local.isDirty) local.updatedAt else if (local == null) System.currentTimeMillis() else 0L
            )

            // If server is newer, equal (for clean local / parse fallback), or no local record, apply server value
            if (local == null || serverUpdatedAt >= local.updatedAt) {
                userPreferencesRepository.updateFromSync(item.key, item.value, serverUpdatedAt)
                Log.d(TAG, "Applied server preference: ${item.key} = ${item.value}")
            }
        }
    }

    private suspend fun pullServerPreferences() {
        when (val result = apiClient.getPreferences()) {
            is NetworkResult.Success -> {
                val response = result.data
                Log.d(TAG, "Pulled ${response.preferences.size} preferences from server")
                applyServerPreferences(response.preferences)
            }
            is NetworkResult.Error -> {
                Log.e(TAG, "Pull preferences error: ${result.code} ${result.message}")
                if (result.code == 401) throw AuthenticationException("pullServerPreferences: 401 Unauthorized")
                // Non-fatal for preferences pull
                Log.w(TAG, "pullServerPreferences failed: ${result.code} ${result.message}")
            }
            is NetworkResult.NetworkError -> throw result.exception
        }
    }

    private fun readPreferenceValue(
        key: String,
        prefs: dev.creapolis.pepinillo.data.local.preferences.UserPreferences,
    ): String? = when (key) {
        "pomodoro_minutes" -> prefs.pomodoroMinutes.toString()
        "short_break_minutes" -> prefs.shortBreakMinutes.toString()
        "long_break_minutes" -> prefs.longBreakMinutes.toString()
        "sessions_before_long_break" -> prefs.sessionsBeforeLongBreak.toString()
        "time_block_minutes" -> prefs.timeBlockMinutes.toString()
        "auto_start_breaks" -> prefs.autoStartBreaks.toString()
        "auto_start_next_pomodoro" -> prefs.autoStartNextPomodoro.toString()
        "sound_enabled" -> prefs.soundEnabled.toString()
        "vibration_enabled" -> prefs.vibrationEnabled.toString()
        "theme_mode" -> prefs.themeMode.name
        "dynamic_color" -> prefs.dynamicColor.toString()
        "selected_theme" -> prefs.selectedTheme
        "keep_screen_on" -> prefs.keepScreenOn.toString()
        "default_mode" -> prefs.defaultMode
        "show_journal_after_session" -> prefs.showJournalAfterSession.toString()
        "flowtime_min_minutes" -> prefs.flowtimeMinMinutes.toString()
        "midpoint_check_in" -> prefs.midpointCheckIn.toString()
        else -> null
    }

    private fun Long.toRfc3339(): String = SyncDateUtils.run { this@toRfc3339.toRfc3339() }

    private fun parseRfc3339(dateString: String?, fallback: Long = 0L): Long =
        SyncDateUtils.parseRfc3339(dateString, fallback)
}
