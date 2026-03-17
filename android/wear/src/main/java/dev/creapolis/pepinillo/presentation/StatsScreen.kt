package dev.creapolis.pepinillo.presentation

import androidx.compose.runtime.Composable
import androidx.wear.compose.material.ScalingLazyColumn
import androidx.wear.compose.material.Text
import dev.creapolis.pepinillo.data.WearStatsState

@Composable
fun StatsScreen(state: WearStatsState) {
    ScalingLazyColumn {
        item { Text(text = "Hoy") }
        item { Text(text = "⏱ ${state.totalMinutes} min") }
        item { Text(text = "✅ ${state.sessions} sesiones") }
        item { Text(text = "🔥 racha ${state.streak}") }
        item { Text(text = "📋 ${state.completedTasks} tareas") }
    }
}
