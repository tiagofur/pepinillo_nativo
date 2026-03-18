package dev.creapolis.pepinillo.presentation

import androidx.compose.foundation.focusable
import androidx.compose.foundation.gestures.scrollBy
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.input.rotary.onRotaryScrollEvent
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.wear.compose.foundation.lazy.ScalingLazyColumn
import androidx.wear.compose.foundation.lazy.items
import androidx.wear.compose.foundation.lazy.rememberScalingLazyListState
import androidx.wear.compose.material.Chip
import androidx.wear.compose.material.ChipDefaults
import androidx.wear.compose.material.ListHeader
import androidx.wear.compose.material.MaterialTheme
import androidx.wear.compose.material.Text
import dev.creapolis.pepinillo.data.WearTask
import dev.creapolis.pepinillo.data.WearTimerState
import kotlinx.coroutines.launch

@Composable
fun TasksScreen(
    tasks: List<WearTask>,
    timerState: WearTimerState? = null,
    syncStatusLabel: String? = null,
    isSyncStale: Boolean = false,
    onCompleteTask: (String) -> Unit,
) {
    val haptics = LocalHapticFeedback.current
    val listState = rememberScalingLazyListState()
    val focusRequester = remember { FocusRequester() }
    val coroutineScope = rememberCoroutineScope()

    val linkedTaskName = timerState?.linkedTaskName
    val isTimerActive = timerState?.status == "Running" || timerState?.status == "Paused"

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
        // Header
        item {
            ListHeader {
                Text(
                    text = "Tareas (${tasks.size})",
                    color = MaterialTheme.colors.primary,
                )
            }
        }

        // Linked task (highlighted) — shown when pomodoro is active with a linked task
        if (isTimerActive && linkedTaskName != null) {
            item {
                Chip(
                    onClick = { },
                    label = {
                        Text(
                            text = linkedTaskName,
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis,
                            color = MaterialTheme.colors.onPrimary,
                        )
                    },
                    secondaryLabel = {
                        Text(
                            text = "🍅 En progreso",
                            style = MaterialTheme.typography.caption2,
                            color = MaterialTheme.colors.onPrimary.copy(alpha = 0.8f),
                        )
                    },
                    icon = {
                        Text(
                            text = "▶",
                            modifier = Modifier.size(24.dp),
                            textAlign = TextAlign.Center,
                            color = MaterialTheme.colors.onPrimary,
                        )
                    },
                    colors = ChipDefaults.primaryChipColors(),
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(vertical = 2.dp),
                )
            }
        }

        // Sync status
        if (!syncStatusLabel.isNullOrBlank()) {
            item {
                Text(
                    text = syncStatusLabel,
                    style = MaterialTheme.typography.caption2,
                    color = if (isSyncStale) MaterialTheme.colors.error else MaterialTheme.colors.onSurfaceVariant,
                    textAlign = TextAlign.Center,
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(bottom = 4.dp),
                )
            }
        }

        if (tasks.isEmpty() && linkedTaskName == null) {
            // Empty state
            item {
                Text(
                    text = "Sin tareas activas",
                    style = MaterialTheme.typography.body2,
                    color = MaterialTheme.colors.onSurfaceVariant,
                    textAlign = TextAlign.Center,
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(top = 16.dp),
                )
            }
        } else {
            items(tasks) { task ->
                val progress = if (task.pomodoroProgress.isNotBlank()) task.pomodoroProgress else null
                Chip(
                    onClick = {
                        haptics.performHapticFeedback(HapticFeedbackType.LongPress)
                        onCompleteTask(task.id)
                    },
                    label = {
                        Text(
                            text = task.title,
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis,
                        )
                    },
                    secondaryLabel = progress?.let {
                        { Text(text = "🍅 $it", style = MaterialTheme.typography.caption2) }
                    },
                    icon = {
                        Text(
                            text = task.energyEmoji,
                            modifier = Modifier.size(24.dp),
                            textAlign = TextAlign.Center,
                        )
                    },
                    colors = ChipDefaults.secondaryChipColors(),
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(vertical = 2.dp),
                )
            }
        }
    }
}
