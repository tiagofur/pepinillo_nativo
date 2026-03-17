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
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.input.rotary.onRotaryScrollEvent
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.unit.dp
import androidx.wear.compose.material.Button
import androidx.wear.compose.material.Text
import androidx.wear.compose.foundation.lazy.ScalingLazyColumn
import androidx.wear.compose.foundation.lazy.items
import androidx.wear.compose.foundation.lazy.rememberScalingLazyListState
import dev.creapolis.pepinillo.data.WearTask
import kotlinx.coroutines.launch

@Composable
fun TasksScreen(
    tasks: List<WearTask>,
    onCompleteTask: (String) -> Unit,
) {
    val haptics = LocalHapticFeedback.current
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
        item {
            Text(text = "Tareas (${tasks.size})")
        }

        if (tasks.isEmpty()) {
            item { Text(text = "Sin tareas activas") }
        } else {
            items(tasks) { task ->
                Button(
                    onClick = {
                        haptics.performHapticFeedback(HapticFeedbackType.LongPress)
                        onCompleteTask(task.id)
                    },
                    modifier = Modifier.padding(vertical = 4.dp),
                ) {
                    val progress = if (task.pomodoroProgress.isNotBlank()) " ${task.pomodoroProgress}" else ""
                    Text("${task.energyEmoji} ${task.title}$progress")
                }
            }
        }
    }
}
