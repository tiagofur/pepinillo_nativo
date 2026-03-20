package dev.creapolis.pepinillo.ui.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import dev.creapolis.pepinillo.feature.focus.FocusMode

data class FocusModeColorScheme(
    val containerColor: Color,
    val contentColor: Color,
    val accentColor: Color,
    val onAccentColor: Color,
)

@Composable
fun FocusMode.colorScheme(): FocusModeColorScheme {
    val theme = LocalAppTheme.current
    val isDark = isSystemInDarkTheme()
    val accent = when (this) {
        FocusMode.Pomodoro -> theme.pomodoroColor
        FocusMode.Flow -> theme.flowtimeColor
        FocusMode.Blocks -> theme.timeBlockColor
        FocusMode.Chrono -> theme.stopwatchColor
    }
    return if (isDark) {
        FocusModeColorScheme(
            containerColor = accent.copy(alpha = 0.15f),
            contentColor = accent,
            accentColor = accent,
            onAccentColor = Color.Black,
        )
    } else {
        FocusModeColorScheme(
            containerColor = accent.copy(alpha = 0.1f),
            contentColor = accent,
            accentColor = accent,
            onAccentColor = Color.White,
        )
    }
}
