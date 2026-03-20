package dev.creapolis.pepinillo.presentation

import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.focusable
import androidx.compose.foundation.gestures.scrollBy
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.input.rotary.onRotaryScrollEvent
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.wear.compose.foundation.lazy.ScalingLazyColumn
import androidx.wear.compose.foundation.lazy.items
import androidx.wear.compose.foundation.lazy.rememberScalingLazyListState
import androidx.wear.compose.material.Button
import androidx.wear.compose.material.ButtonDefaults
import androidx.wear.compose.material.Chip
import androidx.wear.compose.material.ChipDefaults
import androidx.wear.compose.material.ListHeader
import androidx.wear.compose.material.MaterialTheme
import androidx.wear.compose.material.Text
import androidx.wear.compose.material.dialog.Alert
import dev.creapolis.pepinillo.R
import dev.creapolis.pepinillo.data.WearTask
import dev.creapolis.pepinillo.data.WearTimerState
import kotlinx.coroutines.launch

@OptIn(ExperimentalFoundationApi::class)
@Composable
fun TasksScreen(
    tasks: List<WearTask>,
    timerState: WearTimerState? = null,
    syncStatusLabel: String? = null,
    isSyncStale: Boolean = false,
    onCompleteTask: (String) -> Unit,
    onToggleTaskLink: (String, String) -> Unit = { _, _ -> },
    isActive: Boolean = true,
) {
    val haptics = LocalHapticFeedback.current
    val listState = rememberScalingLazyListState()
    val focusRequester = remember { FocusRequester() }
    val coroutineScope = rememberCoroutineScope()

    var taskToComplete by remember { mutableStateOf<WearTask?>(null) }

    LaunchedEffect(isActive) {
        if (isActive) focusRequester.requestFocus()
    }

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
                    text = stringResource(R.string.tasks_count, tasks.size),
                    color = MaterialTheme.colors.primary,
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

        if (tasks.isEmpty()) {
            // Empty state
            item {
                Text(
                    text = stringResource(R.string.no_active_tasks),
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
                val isLinked = timerState?.linkedTaskId == task.id
                Chip(
                    onClick = { },
                    label = {
                        Text(
                            text = task.title,
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis,
                        )
                    },
                    secondaryLabel = if (isLinked) {
                        {
                            Text(
                                text = "🔗 ${stringResource(R.string.linked_to_timer)}",
                                style = MaterialTheme.typography.caption2,
                                color = MaterialTheme.colors.primary,
                            )
                        }
                    } else {
                        progress?.let {
                            { Text(text = "🍅 $it", style = MaterialTheme.typography.caption2) }
                        }
                    },
                    icon = {
                        Text(
                            text = task.energyEmoji,
                            modifier = Modifier.size(24.dp),
                            textAlign = TextAlign.Center,
                        )
                    },
                    colors = if (isLinked) ChipDefaults.primaryChipColors() else ChipDefaults.secondaryChipColors(),
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(vertical = 2.dp)
                        .combinedClickable(
                            onClick = { taskToComplete = task },
                            onLongClick = {
                                haptics.performHapticFeedback(HapticFeedbackType.LongPress)
                                onToggleTaskLink(task.id, task.title)
                            },
                        ),
                )
            }
        }
    }

    // Confirmation dialog
    taskToComplete?.let { task ->
        Alert(
            title = { Text(stringResource(R.string.complete_task), textAlign = TextAlign.Center) },
            message = {
                Text(
                    text = task.title,
                    textAlign = TextAlign.Center,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis,
                )
            },
        ) {
            item {
                Button(
                    onClick = {
                        haptics.performHapticFeedback(HapticFeedbackType.LongPress)
                        onCompleteTask(task.id)
                        taskToComplete = null
                    },
                    colors = ButtonDefaults.primaryButtonColors(),
                ) {
                    Text("✓")
                }
            }
            item {
                Button(
                    onClick = { taskToComplete = null },
                    colors = ButtonDefaults.secondaryButtonColors(),
                ) {
                    Text("✕")
                }
            }
        }
    }
}
