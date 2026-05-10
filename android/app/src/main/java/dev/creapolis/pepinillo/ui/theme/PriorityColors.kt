package dev.creapolis.pepinillo.ui.theme

import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import dev.creapolis.pepinillo.feature.tasks.model.TaskPriority

@Composable
fun TaskPriority.priorityColor(): Color {
    return when (this) {
        TaskPriority.High -> MaterialTheme.colorScheme.error
        TaskPriority.Medium -> MaterialTheme.colorScheme.tertiary
        TaskPriority.Low -> MaterialTheme.colorScheme.secondary
        TaskPriority.None -> Color.Transparent
    }
}
