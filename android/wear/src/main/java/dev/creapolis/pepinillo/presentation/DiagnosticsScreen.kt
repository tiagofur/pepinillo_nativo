package dev.creapolis.pepinillo.presentation

import androidx.compose.foundation.focusable
import androidx.compose.foundation.gestures.scrollBy
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.input.rotary.onRotaryScrollEvent
import androidx.compose.ui.unit.dp
import androidx.wear.compose.foundation.lazy.ScalingLazyColumn
import androidx.wear.compose.foundation.lazy.rememberScalingLazyListState
import androidx.wear.compose.material3.MaterialTheme
import androidx.wear.compose.material3.Text
import dev.creapolis.pepinillo.data.WearDiagnosticsState
import dev.creapolis.pepinillo.data.WearStatsState
import dev.creapolis.pepinillo.data.WearTask
import dev.creapolis.pepinillo.data.WearTimerState
import kotlinx.coroutines.launch

@Composable
fun DiagnosticsScreen(
    timerState: WearTimerState,
    tasks: List<WearTask>,
    stats: WearStatsState,
    pendingCommandCount: Int,
    syncStatusLabel: String?,
    isSyncStale: Boolean,
    diagnostics: WearDiagnosticsState,
) {
    val listState = rememberScalingLazyListState()
    val focusRequester = remember { FocusRequester() }
    val coroutineScope = rememberCoroutineScope()

    LaunchedEffect(Unit) { focusRequester.requestFocus() }

    ScalingLazyColumn(
        state = listState,
        modifier = Modifier
            .fillMaxSize()
            .onRotaryScrollEvent { event ->
                coroutineScope.launch { listState.scrollBy(event.verticalScrollPixels) }
                true
            }
            .focusRequester(focusRequester)
            .focusable(),
    ) {
        item { Text("Diagnostico") }
        item {
            Text(
                text = syncStatusLabel ?: "Sin sync registrada",
                style = MaterialTheme.typography.labelSmall,
                color = if (isSyncStale) MaterialTheme.colorScheme.error else MaterialTheme.colorScheme.onSurface,
            )
        }
        item { Text("Conexion: ${if (timerState.isConnected) "Activa" else "Caida"}") }
        item { Text("Peers Data Layer: ${diagnostics.connectedNodeCount}") }
        diagnostics.connectedNodeNames.takeIf { it.isNotEmpty() }?.let { names ->
            item {
                Text(
                    text = "Nodos: ${names.joinToString()}",
                    style = MaterialTheme.typography.labelSmall,
                )
            }
        }
        item { Text("Timer: ${timerState.status} · ${timerState.displayTime}") }
        item { Text("Modo/Fase: ${timerState.mode} · ${timerState.phaseLabel}") }
        item { Text("Cola offline: $pendingCommandCount") }
        item { Text("Sync events: ${diagnostics.syncEvents}") }
        item { Text("Sync failures: ${diagnostics.syncFailures}") }
        item { Text("Flush attempts: ${diagnostics.flushAttempts}") }
        item { Text("Flush failures: ${diagnostics.flushFailures}") }
        diagnostics.lastError?.takeIf { it.isNotBlank() }?.let { error ->
            item {
                Text(
                    text = "Ultimo error: $error",
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.error,
                )
            }
        }
        item { Text("Tareas activas: ${tasks.size}") }
        item { Text("Stats hoy: ${stats.sessions} ses / ${stats.totalMinutes} min") }
        item { Text("Racha: ${stats.streak} · Completadas: ${stats.completedTasks}") }
        item {
            Text(
                "Checklist rapido:\n1) Corta BT/WiFi telefono\n2) Lanza comando en reloj\n3) Re-conecta\n4) Verifica cola=0",
                style = MaterialTheme.typography.labelSmall,
                modifier = Modifier.padding(vertical = 4.dp),
            )
        }
    }
}
