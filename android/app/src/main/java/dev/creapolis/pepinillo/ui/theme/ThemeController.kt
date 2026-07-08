package dev.creapolis.pepinillo.ui.theme

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

enum class ThemeMode(val label: String) {
    System("System"),
    Light("Light"),
    Dark("Dark"),
}

/**
 * App-wide theme state. Backed by DataStore via [seedFrom], which the Application
 * calls at startup so persisted theme prefs are applied before the first frame —
 * preventing a theme flash on cold start for users with non-default prefs.
 */
object ThemeController {
    private val _themeMode = MutableStateFlow(ThemeMode.System)
    val themeMode: StateFlow<ThemeMode> = _themeMode.asStateFlow()

    private val _dynamicColor = MutableStateFlow(true)
    val dynamicColor: StateFlow<Boolean> = _dynamicColor.asStateFlow()

    fun setThemeMode(mode: ThemeMode) {
        _themeMode.value = mode
    }

    fun setDynamicColor(enabled: Boolean) {
        _dynamicColor.value = enabled
    }

    private val _selectedTheme = MutableStateFlow("materialYou")
    val selectedTheme: StateFlow<String> = _selectedTheme.asStateFlow()

    fun setSelectedTheme(id: String) {
        _selectedTheme.value = id
        _dynamicColor.value = (id == "materialYou")
    }

    /**
     * Whether [seedFrom] has applied persisted preferences at least once.
     * The splash screen waits on this to avoid showing the default theme before
     * the user's saved theme is active.
     */
    private val _isSeeded = MutableStateFlow(false)
    val isSeeded: StateFlow<Boolean> = _isSeeded.asStateFlow()

    /**
     * Apply a snapshot of persisted preferences. Marked seeded on first call.
     * Subsequent calls (e.g. from the Settings screen's collector) refresh state
     * but don't need to gate the splash again.
     */
    fun seedFrom(mode: ThemeMode, dynamic: Boolean, themeId: String) {
        // Preserve explicit dynamicColor relationship used by setSelectedTheme.
        _themeMode.value = mode
        _selectedTheme.value = themeId
        _dynamicColor.value = if (themeId == "materialYou") true else dynamic
        _isSeeded.value = true
    }
}
