package dev.creapolis.pepinillo.presentation

import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.graphics.Color
import androidx.wear.compose.material3.ColorScheme
import androidx.wear.compose.material3.MaterialTheme
import dev.creapolis.pepinillo.data.WearDataStore

// Pepinillo dark palette — consistent with phone app dark theme
// OLED-friendly: true black background for battery savings on Wear
// Note: Wear M3 ColorScheme has no "surface" token; use surfaceContainer/surfaceContainerLow/High.
private val PepinilloWearColorScheme = ColorScheme(
    primary = Color(0xFF9CD67D),                // Pepinillo green
    onPrimary = Color(0xFF0B3900),
    primaryContainer = Color(0xFF205107),        // dark green container
    onPrimaryContainer = Color(0xFFB7F397),
    secondary = Color(0xFF81C784),              // Lighter green accent
    onSecondary = Color(0xFF0A290A),
    secondaryContainer = Color(0xFF1A3A1A),
    onSecondaryContainer = Color(0xFF9DE09D),
    tertiary = Color(0xFF52B788),
    onTertiary = Color(0xFF003828),
    tertiaryContainer = Color(0xFF005140),
    onTertiaryContainer = Color(0xFF70D4A5),
    error = Color(0xFFFFB4AB),
    onError = Color(0xFF690005),
    errorContainer = Color(0xFF93000A),
    onErrorContainer = Color(0xFFFFDAD6),
    background = Color(0xFF0A0C08),             // Near-black for OLED
    onBackground = Color(0xFFE2E3D8),
    surfaceContainerLow = Color(0xFF131510),    // replaces M2 "surface"
    surfaceContainer = Color(0xFF1A1C18),       // main surface token
    surfaceContainerHigh = Color(0xFF242620),
    onSurface = Color(0xFFE2E3D8),
    onSurfaceVariant = Color(0xFFC3C8BB),
    outline = Color(0xFF8D9286),
    outlineVariant = Color(0xFF424940),
)

// Focus mode accent colors for timer ring and mode-specific UI.
// Colors are synced from the phone app via WearDataStore; defaults match the Classic theme.
object WearModeColors {
    val Pomodoro: Color @Composable get() {
        val theme by WearDataStore.themeColors.collectAsState()
        return Color(theme.pomodoroColor.toInt())
    }
    val Flow: Color @Composable get() {
        val theme by WearDataStore.themeColors.collectAsState()
        return Color(theme.flowtimeColor.toInt())
    }
    val Blocks: Color @Composable get() {
        val theme by WearDataStore.themeColors.collectAsState()
        return Color(theme.timeBlockColor.toInt())
    }
    val Chrono: Color @Composable get() {
        val theme by WearDataStore.themeColors.collectAsState()
        return Color(theme.stopwatchColor.toInt())
    }

    @Composable
    fun forMode(mode: String): Color = when (mode) {
        "Pomodoro" -> Pomodoro
        "Flow" -> Flow
        "Blocks" -> Blocks
        "Chrono" -> Chrono
        else -> Pomodoro
    }

    @Composable
    fun forModeAndPhase(mode: String, phase: String): Color {
        val base = forMode(mode)
        return when (phase) {
            "ShortBreak" -> base.shortBreakVariant()
            "LongBreak" -> base.longBreakVariant()
            else -> base
        }
    }
}

@Composable
fun WearTheme(content: @Composable () -> Unit) {
    MaterialTheme(
        colorScheme = PepinilloWearColorScheme,
        typography = WearTypography,
        content = content,
    )
}
