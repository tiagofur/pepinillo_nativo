package dev.creapolis.pepinillo.presentation

import androidx.compose.foundation.focusable
import androidx.compose.foundation.gestures.scrollBy
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.input.rotary.onRotaryScrollEvent
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.wear.compose.foundation.lazy.ScalingLazyColumn
import androidx.wear.compose.foundation.lazy.rememberScalingLazyListState
import androidx.wear.compose.material3.ListHeader
import androidx.wear.compose.material3.MaterialTheme
import androidx.wear.compose.material3.SwitchButton
import androidx.wear.compose.material3.Text
import dev.creapolis.pepinillo.R
import dev.creapolis.pepinillo.data.WearDiagnosticsState
import dev.creapolis.pepinillo.data.WearStatsState
import dev.creapolis.pepinillo.data.WearTask
import dev.creapolis.pepinillo.data.WearTimerState
import kotlinx.coroutines.launch

private const val WEAR_PRIVACY_HEADER = "Privacidad"
private const val WEAR_METRICS_OPT_IN_LABEL = "Compartir métricas anónimas"
private const val WEAR_METRICS_OPT_IN_CONSENT_COPY =
    "Comparte métricas de uso anónimas y agregadas para mejorar Pepinillo: cuántas sesiones de enfoque se completan y en qué modos, minutos totales de enfoque y descanso, y tareas creadas y completadas. Nunca se comparte el contenido de tus tareas, tus horarios individuales ni ningún dato identificable. Puedes cambiarlo cuando quieras."
private const val WEAR_METRICS_REQUIRES_ACCOUNT_HINT = "Requiere cuenta con sincronización"

@Composable
fun DiagnosticsScreen(
    timerState: WearTimerState,
    tasks: List<WearTask>,
    stats: WearStatsState,
    pendingCommandCount: Int,
    syncStatusLabel: String?,
    isSyncStale: Boolean,
    diagnostics: WearDiagnosticsState,
    isActive: Boolean = true,
    isLoggedIn: Boolean = false,
    metricsOptIn: Boolean = false,
    metricsOptInError: String? = null,
    onToggleMetricsOptIn: (Boolean) -> Unit = {},
) {
    val listState = rememberScalingLazyListState()
    val focusRequester = remember { FocusRequester() }
    val coroutineScope = rememberCoroutineScope()

    // Only steal rotary/crown focus while this page is the settled pager page,
    // matching Stats/Tasks — the pager pre-composes neighbour pages.
    LaunchedEffect(isActive) { if (isActive) focusRequester.requestFocus() }

    val diagTitle = stringResource(R.string.diag_title)
    val diagNoSync = stringResource(R.string.diag_no_sync)
    val connectionState = if (timerState.isConnected) {
        stringResource(R.string.diag_connection_active)
    } else {
        stringResource(R.string.diag_connection_down)
    }

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
        item {
            ListHeader {
                Text(
                    text = WEAR_PRIVACY_HEADER,
                    color = MaterialTheme.colorScheme.primary,
                )
            }
        }
        item {
            SwitchButton(
                checked = if (isLoggedIn) metricsOptIn else false,
                onCheckedChange = { onToggleMetricsOptIn(it) },
                enabled = isLoggedIn,
                modifier = Modifier.fillMaxWidth(),
                label = {
                    Text(
                        text = WEAR_METRICS_OPT_IN_LABEL,
                        style = MaterialTheme.typography.labelMedium,
                    )
                },
            )
        }
        if (!isLoggedIn) {
            item {
                Text(
                    text = WEAR_METRICS_REQUIRES_ACCOUNT_HINT,
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.padding(horizontal = 8.dp, vertical = 2.dp),
                )
            }
        }
        metricsOptInError?.takeIf { it.isNotBlank() }?.let { errorMsg ->
            item {
                Text(
                    text = errorMsg,
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.error,
                    modifier = Modifier.padding(horizontal = 8.dp, vertical = 2.dp),
                )
            }
        }
        item {
            Text(
                text = WEAR_METRICS_OPT_IN_CONSENT_COPY,
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp),
            )
        }
        item { Text(diagTitle) }
        item {
            Text(
                text = syncStatusLabel ?: diagNoSync,
                style = MaterialTheme.typography.labelSmall,
                color = if (isSyncStale) MaterialTheme.colorScheme.error else MaterialTheme.colorScheme.onSurface,
            )
        }
        item { Text(stringResource(R.string.diag_connection, connectionState)) }
        item { Text(stringResource(R.string.diag_peers, diagnostics.connectedNodeCount)) }
        diagnostics.connectedNodeNames.takeIf { it.isNotEmpty() }?.let { names ->
            item {
                Text(
                    text = stringResource(R.string.diag_nodes, names.joinToString()),
                    style = MaterialTheme.typography.labelSmall,
                )
            }
        }
        item { Text(stringResource(R.string.diag_timer, timerState.status, timerState.displayTime)) }
        item { Text(stringResource(R.string.diag_mode_phase, timerState.mode, timerState.phaseLabel)) }
        item { Text(stringResource(R.string.diag_offline_queue, pendingCommandCount)) }
        item { Text(stringResource(R.string.diag_sync_events, diagnostics.syncEvents)) }
        item { Text(stringResource(R.string.diag_sync_failures, diagnostics.syncFailures)) }
        item { Text(stringResource(R.string.diag_flush_attempts, diagnostics.flushAttempts)) }
        item { Text(stringResource(R.string.diag_flush_failures, diagnostics.flushFailures)) }
        diagnostics.lastError?.takeIf { it.isNotBlank() }?.let { error ->
            item {
                Text(
                    text = stringResource(R.string.diag_last_error, error),
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.error,
                )
            }
        }
        item { Text(stringResource(R.string.diag_active_tasks, tasks.size)) }
        item { Text(stringResource(R.string.diag_stats_today, stats.sessions, stats.totalMinutes)) }
        item { Text(stringResource(R.string.diag_streak, stats.streak, stats.completedTasks)) }
        item {
            Text(
                stringResource(R.string.diag_checklist),
                style = MaterialTheme.typography.labelSmall,
                modifier = Modifier.padding(vertical = 4.dp),
            )
        }
    }
}
