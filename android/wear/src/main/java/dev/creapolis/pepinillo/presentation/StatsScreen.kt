package dev.creapolis.pepinillo.presentation

import androidx.compose.foundation.focusable
import androidx.compose.foundation.gestures.scrollBy
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.input.rotary.onRotaryScrollEvent
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.wear.compose.foundation.lazy.ScalingLazyColumn
import androidx.wear.compose.foundation.lazy.rememberScalingLazyListState
import androidx.wear.compose.material.Chip
import androidx.wear.compose.material.ChipDefaults
import androidx.wear.compose.material.ListHeader
import androidx.wear.compose.material.MaterialTheme
import androidx.wear.compose.material.Text
import dev.creapolis.pepinillo.R
import dev.creapolis.pepinillo.data.WearStatsState
import kotlinx.coroutines.launch

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Lock
import androidx.wear.compose.material.Icon

@Composable
fun StatsScreen(
    state: WearStatsState,
    syncStatusLabel: String? = null,
    isSyncStale: Boolean = false,
    isPro: Boolean = false,
    isActive: Boolean = true,
) {
    val listState = rememberScalingLazyListState()
    val focusRequester = remember { FocusRequester() }
    val coroutineScope = rememberCoroutineScope()

    LaunchedEffect(isActive) {
        if (isActive) focusRequester.requestFocus()
    }

    if (!isPro) {
        Box(
            modifier = Modifier.fillMaxSize(),
            contentAlignment = Alignment.Center,
        ) {
            Column(
                horizontalAlignment = Alignment.CenterHorizontally,
                modifier = Modifier.padding(horizontal = 16.dp),
            ) {
                Icon(
                    imageVector = Icons.Default.Lock,
                    contentDescription = "Locked",
                    modifier = Modifier.size(24.dp),
                    tint = MaterialTheme.colors.primary,
                )
                androidx.compose.foundation.layout.Spacer(modifier = Modifier.height(8.dp))
                Text(
                    text = "Unlock detailed stats with Pepinillo Pro",
                    style = MaterialTheme.typography.caption2,
                    textAlign = TextAlign.Center,
                    color = MaterialTheme.colors.onSurface,
                )
            }
        }
        return
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
                    text = stringResource(R.string.today),
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

        // Focus time
        item {
            StatChip(
                emoji = "⏱",
                label = stringResource(R.string.focus_time),
                value = formatMinutes(state.totalMinutes),
            )
        }

        // Sessions
        item {
            StatChip(
                emoji = "✅",
                label = stringResource(R.string.sessions),
                value = "${state.sessions}",
            )
        }

        // Streak
        item {
            StatChip(
                emoji = "🔥",
                label = stringResource(R.string.streak),
                value = stringResource(R.string.days, state.streak),
            )
        }

        // Completed tasks
        item {
            StatChip(
                emoji = "📋",
                label = stringResource(R.string.completed_tasks),
                value = "${state.completedTasks}",
            )
        }
    }
}

@Composable
private fun StatChip(
    emoji: String,
    label: String,
    value: String,
) {
    Chip(
        onClick = { },
        enabled = false,
        label = {
            Text(
                text = value,
                color = MaterialTheme.colors.primary,
            )
        },
        secondaryLabel = {
            Text(
                text = label,
                style = MaterialTheme.typography.caption2,
            )
        },
        icon = {
            Text(
                text = emoji,
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

private fun formatMinutes(totalMinutes: Int): String {
    val hours = totalMinutes / 60
    val minutes = totalMinutes % 60
    return if (hours > 0) "${hours}h ${minutes}m" else "${minutes}m"
}
