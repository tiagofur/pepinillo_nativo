package dev.creapolis.pepinillo.ui.theme

import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

/**
 * Centralized, theme-aware colors for energy levels and focus modes.
 * Adapts to light/dark theme via MaterialTheme.colorScheme.
 */
object EnergyColors {
    val deep: Color @Composable get() = MaterialTheme.colorScheme.primary
    val regular: Color @Composable get() = MaterialTheme.colorScheme.tertiary
    val light: Color @Composable get() = MaterialTheme.colorScheme.secondary
}

object ModeColors {
    val pomodoro: Color @Composable get() = MaterialTheme.colorScheme.primary
    val flow: Color @Composable get() = MaterialTheme.colorScheme.secondary
    val blocks: Color @Composable get() = MaterialTheme.colorScheme.tertiary
    val chrono: Color @Composable get() = MaterialTheme.colorScheme.inversePrimary
}
