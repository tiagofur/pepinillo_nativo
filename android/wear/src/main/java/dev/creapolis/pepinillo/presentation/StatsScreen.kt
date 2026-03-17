package dev.creapolis.pepinillo.presentation

import androidx.compose.foundation.focusable
import androidx.compose.foundation.gestures.scrollBy
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.input.rotary.onRotaryScrollEvent
import androidx.wear.compose.foundation.lazy.ScalingLazyColumn
import androidx.wear.compose.foundation.lazy.rememberScalingLazyListState
import androidx.wear.compose.material.MaterialTheme
import androidx.wear.compose.material.Text
import dev.creapolis.pepinillo.data.WearStatsState
import kotlinx.coroutines.launch

@Composable
fun StatsScreen(
    state: WearStatsState,
    syncStatusLabel: String? = null,
    isSyncStale: Boolean = false,
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
                coroutineScope.launch {
                    listState.scrollBy(event.verticalScrollPixels)
                }
                true
            }
            .focusRequester(focusRequester)
            .focusable(),
    ) {
        item { Text(text = "Hoy") }
        if (!syncStatusLabel.isNullOrBlank()) {
            item {
                Text(
                    text = syncStatusLabel,
                    style = MaterialTheme.typography.caption3,
                    color = if (isSyncStale) MaterialTheme.colors.error else MaterialTheme.colors.onSurface,
                )
            }
        }
        item { Text(text = "⏱ ${state.totalMinutes} min") }
        item { Text(text = "✅ ${state.sessions} sesiones") }
        item { Text(text = "🔥 racha ${state.streak}") }
        item { Text(text = "📋 ${state.completedTasks} tareas") }
    }
}
