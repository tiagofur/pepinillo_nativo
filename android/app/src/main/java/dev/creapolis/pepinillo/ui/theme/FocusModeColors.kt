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
    val isDark = isSystemInDarkTheme()
    return when (this) {
        FocusMode.Pomodoro -> if (isDark) {
            FocusModeColorScheme(
                containerColor = Color(0xFF1A3A1A),
                contentColor = Color(0xFFC8E6C9),
                accentColor = Color(0xFF81C784),
                onAccentColor = Color(0xFF0A290A),
            )
        } else {
            FocusModeColorScheme(
                containerColor = Color(0xFFE8F5E9),
                contentColor = Color(0xFF1B5E20),
                accentColor = Color(0xFF43A047),
                onAccentColor = Color.White,
            )
        }

        FocusMode.Flow -> if (isDark) {
            FocusModeColorScheme(
                containerColor = Color(0xFF142A3E),
                contentColor = Color(0xFFBBDEFB),
                accentColor = Color(0xFF64B5F6),
                onAccentColor = Color(0xFF0A1929),
            )
        } else {
            FocusModeColorScheme(
                containerColor = Color(0xFFE3F2FD),
                contentColor = Color(0xFF1565C0),
                accentColor = Color(0xFF1E88E5),
                onAccentColor = Color.White,
            )
        }

        FocusMode.Blocks -> if (isDark) {
            FocusModeColorScheme(
                containerColor = Color(0xFF3E2A14),
                contentColor = Color(0xFFFFE0B2),
                accentColor = Color(0xFFFFB74D),
                onAccentColor = Color(0xFF291A0A),
            )
        } else {
            FocusModeColorScheme(
                containerColor = Color(0xFFFFF3E0),
                contentColor = Color(0xFFE65100),
                accentColor = Color(0xFFFB8C00),
                onAccentColor = Color.White,
            )
        }

        FocusMode.Chrono -> if (isDark) {
            FocusModeColorScheme(
                containerColor = Color(0xFF2A1A3E),
                contentColor = Color(0xFFE1BEE7),
                accentColor = Color(0xFFCE93D8),
                onAccentColor = Color(0xFF1A0A29),
            )
        } else {
            FocusModeColorScheme(
                containerColor = Color(0xFFF3E5F5),
                contentColor = Color(0xFF6A1B9A),
                accentColor = Color(0xFF8E24AA),
                onAccentColor = Color.White,
            )
        }
    }
}
