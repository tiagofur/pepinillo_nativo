package dev.creapolis.pepinillo.ui.theme

import android.content.Context
import android.provider.Settings
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.platform.LocalContext
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

/**
 * Whether the app should use dark colors, respecting the user's explicit [ThemeMode] choice.
 *
 * Use this instead of `isSystemInDarkTheme()` everywhere except the single sanctioned call site
 * in MainActivity that resolves `ThemeMode.System`. Leaf components that call `isSystemInDarkTheme()`
 * directly ignore a user who explicitly picked Light or Dark (#397).
 */
@Composable
fun isAppInDarkTheme(): Boolean {
    val themeMode by ThemeController.themeMode.collectAsState()
    return when (themeMode) {
        ThemeMode.System -> isSystemInDarkTheme()
        ThemeMode.Light -> false
        ThemeMode.Dark -> true
    }
}

/**
 * Whether the user has enabled "Remove animations" / "Reduce motion" in system accessibility
 * settings. When true, infinite animations (breathe, shimmer, ring pulse) should fall back to
 * static visuals, and bouncy springs should use non-bouncy specs (#401).
 */
@Composable
fun isReduceMotionEnabled(): Boolean {
    val context = LocalContext.current
    return try {
        val scale = Settings.Global.getFloat(
            context.contentResolver,
            Settings.Global.ANIMATOR_DURATION_SCALE,
            1f,
        )
        scale == 0f
    } catch (_: Exception) {
        false
    }
}
