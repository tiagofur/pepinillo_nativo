package dev.creapolis.pepinillo.presentation

import androidx.compose.foundation.focusable
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.gestures.scrollBy
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.input.rotary.onRotaryScrollEvent
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.wear.compose.foundation.lazy.ScalingLazyColumn
import androidx.wear.compose.foundation.lazy.items
import androidx.wear.compose.foundation.lazy.rememberScalingLazyListState
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Close
import androidx.wear.compose.material3.AlertDialog
import androidx.wear.compose.material3.Button
import androidx.wear.compose.material3.ButtonDefaults
import androidx.wear.compose.material3.FilledTonalButton
import androidx.wear.compose.material3.Icon
import androidx.wear.compose.material3.ListHeader
import androidx.wear.compose.material3.MaterialTheme
import androidx.wear.compose.material3.OutlinedButton
import androidx.wear.compose.material3.Text
import dev.creapolis.pepinillo.R
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
                    color = MaterialTheme.colorScheme.primary,
                )
            }
        }

        // Sync status
        if (!syncStatusLabel.isNullOrBlank()) {
            item {
                Text(
                    text = syncStatusLabel,
                    style = MaterialTheme.typography.labelSmall,
                    color = if (isSyncStale) MaterialTheme.colorScheme.error else MaterialTheme.colorScheme.onSurfaceVariant,
                    textAlign = TextAlign.Center,
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(bottom = 4.dp),
                )
            }
        }

        if (tasks.isEmpty()) {
            item {
                Text(
                    text = stringResource(R.string.no_active_tasks),
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
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
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(vertical = 2.dp),
                ) {
                    // M3 has no Chip — use FilledTonalButton (linked) or OutlinedButton (normal)
                    // with a custom column layout to replicate label + secondaryLabel + icon.
                    val buttonColors = if (isLinked) {
                        ButtonDefaults.buttonColors(
                            containerColor = MaterialTheme.colorScheme.primaryContainer,
                            contentColor = MaterialTheme.colorScheme.onPrimaryContainer,
                        )
                    } else {
                        ButtonDefaults.filledTonalButtonColors()
                    }
                    FilledTonalButton(
                        onClick = { },
                        modifier = Modifier.fillMaxWidth(),
                        colors = buttonColors,
                        shape = RoundedCornerShape(12.dp),
                    ) {
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(8.dp),
                        ) {
                            Text(
                                text = task.energyEmoji,
                                modifier = Modifier.size(24.dp),
                                textAlign = TextAlign.Center,
                            )
                            Column(modifier = Modifier.weight(1f)) {
                                Text(
                                    text = task.title,
                                    maxLines = 1,
                                    overflow = TextOverflow.Ellipsis,
                                    style = MaterialTheme.typography.labelMedium,
                                )
                                when {
                                    isLinked -> Text(
                                        text = "🔗 ${stringResource(R.string.linked_to_timer)}",
                                        style = MaterialTheme.typography.labelSmall,
                                        color = MaterialTheme.colorScheme.primary,
                                    )
                                    progress != null -> Text(
                                        text = "🍅 $progress",
                                        style = MaterialTheme.typography.labelSmall,
                                    )
                                }
                            }
                        }
                    }
                    // Transparent overlay intercepts touch events before button's internal handler
                    Box(
                        modifier = Modifier
                            .matchParentSize()
                            .pointerInput(task.id) {
                                detectTapGestures(
                                    onTap = { taskToComplete = task },
                                    onLongPress = {
                                        WearHaptics.onConfirm(haptics)
                                        onToggleTaskLink(task.id, task.title)
                                    },
                                )
                            },
                    )
                }
            }
        }
    }

    // Confirmation dialog — M3 AlertDialog replaces M2 Alert { item { } } pattern
    taskToComplete?.let { task ->
        AlertDialog(
            visible = true,
            onDismissRequest = { taskToComplete = null },
            confirmButton = {
                Button(
                    onClick = {
                        WearHaptics.onConfirm(haptics)
                        onCompleteTask(task.id)
                        taskToComplete = null
                    },
                    colors = ButtonDefaults.buttonColors(
                        containerColor = MaterialTheme.colorScheme.primary,
                        contentColor = MaterialTheme.colorScheme.onPrimary,
                    ),
                ) {
                    Icon(
                        imageVector = Icons.Filled.Check,
                        contentDescription = stringResource(R.string.complete_task),
                        modifier = Modifier.size(24.dp),
                    )
                }
            },
            title = {
                Text(
                    text = stringResource(R.string.complete_task),
                    textAlign = TextAlign.Center,
                    fontWeight = FontWeight.Bold,
                )
            },
            dismissButton = {
                OutlinedButton(
                    onClick = { taskToComplete = null },
                ) {
                    Icon(
                        imageVector = Icons.Filled.Close,
                        contentDescription = stringResource(R.string.cancel),
                        modifier = Modifier.size(24.dp),
                    )
                }
            },
            text = {
                Text(
                    text = task.title,
                    textAlign = TextAlign.Center,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis,
                )
            },
        )
    }
}
