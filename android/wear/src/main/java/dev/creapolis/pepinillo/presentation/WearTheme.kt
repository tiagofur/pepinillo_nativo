package dev.creapolis.pepinillo.presentation

import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.graphics.Color
import androidx.wear.compose.material.Colors
import androidx.wear.compose.material.MaterialTheme
import dev.creapolis.pepinillo.data.WearDataStore

// Pepinillo dark palette — consistent with phone app dark theme
// OLED-friendly: true black background for battery savings on Wear
private val PepinilloWearColors = Colors(
    primary = Color(0xFF9CD67D),          // Pepinillo green (dark primary)
    primaryVariant = Color(0xFF205107),    // Deep green container
    secondary = Color(0xFF81C784),        // Lighter green accent
    secondaryVariant = Color(0xFF1A3A1A),
    background = Color(0xFF0A0C08),       // Near-black for OLED
    surface = Color(0xFF1A1C18),          // Subtle dark surface
    error = Color(0xFFFFB4AB),
    onPrimary = Color(0xFF0B3900),
    onSecondary = Color(0xFF0A290A),
    onBackground = Color(0xFFE2E3D8),
    onSurface = Color(0xFFE2E3D8),
    onSurfaceVariant = Color(0xFFC3C8BB),
    onError = Color(0xFF690005),
)

// Focus mode accent colors for timer ring and mode-specific UI
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
        colors = PepinilloWearColors,
        content = content,
    )
}
