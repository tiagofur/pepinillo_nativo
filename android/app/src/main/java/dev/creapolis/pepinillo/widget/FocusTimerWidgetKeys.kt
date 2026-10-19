package dev.creapolis.pepinillo.widget

import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.floatPreferencesKey
import androidx.datastore.preferences.core.intPreferencesKey
import androidx.datastore.preferences.core.stringPreferencesKey

internal object FocusTimerWidgetKeys {
    val MODE = stringPreferencesKey("mode")
    val SELECTED_MODE = stringPreferencesKey("selected_mode")
    val DISPLAY = stringPreferencesKey("display")
    val PHASE = stringPreferencesKey("phase")
    val STATUS = stringPreferencesKey("status")
    val PROGRESS = floatPreferencesKey("progress")
    val FINISH_TIMESTAMP = stringPreferencesKey("finish_timestamp")
    val LINKED_TASK = stringPreferencesKey("linked_task")
    val FOCUS_IS_PRO = booleanPreferencesKey("is_pro")
    val ELAPSED = stringPreferencesKey("elapsed_millis")
    val ELAPSED_REALTIME_ANCHOR = stringPreferencesKey("elapsed_realtime_anchor")
    val STREAK = intPreferencesKey("streak")
    val SESSIONS = intPreferencesKey("sessions")
    val LINKED_TASK_TITLE = stringPreferencesKey("linked_task_title")
    val THEME_ID = stringPreferencesKey("selected_theme")
    val PHASE_ENUM = stringPreferencesKey("phase_enum")
    val THEME_MODE = stringPreferencesKey("theme_mode")
}