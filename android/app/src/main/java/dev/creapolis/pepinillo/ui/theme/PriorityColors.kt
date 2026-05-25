package dev.creapolis.pepinillo.ui.theme

import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import dev.creapolis.pepinillo.feature.tasks.model.TaskPriority

// Fixed semantic colors — must NOT use MaterialTheme because Dynamic Color
// can map secondary/tertiary to anything depending on the wallpaper.
@Composable
fun TaskPriority.priorityColor(): Color = when (this) {
    TaskPriority.High   -> Color(0xFFE53935) // red
    TaskPriority.Medium -> Color(0xFFFB8C00) // orange
    TaskPriority.Low    -> Color(0xFF1E88E5) // blue
    TaskPriority.None   -> Color.Transparent
}
