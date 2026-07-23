package dev.creapolis.pepinillo.presentation

import androidx.compose.foundation.focusable
import androidx.compose.foundation.gestures.scrollBy
import androidx.compose.foundation.layout.Arrangement
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
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Lock
import androidx.wear.compose.material3.FilledTonalButton
import androidx.wear.compose.material3.ButtonDefaults
import androidx.wear.compose.material3.Icon
import androidx.wear.compose.material3.ListHeader
import androidx.wear.compose.material3.MaterialTheme
import androidx.wear.compose.material3.Text
import dev.creapolis.pepinillo.R
import dev.creapolis.pepinillo.data.WearStatsState
import kotlinx.coroutines.launch

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
        // Tease value: show today's focus time + sessions (free), gate history/streak behind Pro.
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
                ListHeader {
                    Text(
                        text = stringResource(R.string.today),
                        color = MaterialTheme.colorScheme.primary,
                    )
                }
            }
            item {
                StatRow(
                    emoji = "⏱",
                    label = stringResource(R.string.focus_time),
                    value = formatMinutes(state.totalMinutes),
                )
            }
            item {
                StatRow(
                    emoji = "✅",
                    label = stringResource(R.string.sessions),
                    value = "${state.sessions}",
                )
            }
            item { Spacer(modifier = Modifier.height(8.dp)) }
            item {
                ListHeader {
                    Text(
                        text = stringResource(R.string.stats_unlock_history),
                        color = MaterialTheme.colorScheme.primary,
                    )
                }
            }
            item {
                Column(
                    horizontalAlignment = Alignment.CenterHorizontally,
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 16.dp),
                ) {
                    Icon(
                        imageVector = Icons.Default.Lock,
                        contentDescription = null,
                        modifier = Modifier.size(20.dp),
                        tint = MaterialTheme.colorScheme.primary,
                    )
                    Spacer(modifier = Modifier.height(4.dp))
                    Text(
                        text = stringResource(R.string.stats_unlock_desc),
                        style = MaterialTheme.typography.labelSmall,
                        textAlign = TextAlign.Center,
                        color = MaterialTheme.colorScheme.onSurface,
                    )
                }
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
        item {
            ListHeader {
                Text(
                    text = stringResource(R.string.today),
                    color = MaterialTheme.colorScheme.primary,
                )
            }
        }

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

        item {
            StatRow(
                emoji = "⏱",
                label = stringResource(R.string.focus_time),
                value = formatMinutes(state.totalMinutes),
            )
        }
        item {
            StatRow(
                emoji = "✅",
                label = stringResource(R.string.sessions),
                value = "${state.sessions}",
            )
        }
        item {
            StatRow(
                emoji = "🔥",
                label = stringResource(R.string.streak),
                value = stringResource(R.string.days, state.streak),
            )
        }
        item {
            StatRow(
                emoji = "📋",
                label = stringResource(R.string.completed_tasks),
                value = "${state.completedTasks}",
            )
        }
    }
}

/**
 * Read-only stat row using FilledTonalButton as a visual container.
 * M3 has no Chip component — FilledTonalButton with disabled=true serves as a
 * non-interactive display element with the correct tonal surface color.
 */
@Composable
private fun StatRow(
    emoji: String,
    label: String,
    value: String,
) {
    FilledTonalButton(
        onClick = { },
        enabled = false,
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 2.dp),
        shape = RoundedCornerShape(12.dp),
        colors = ButtonDefaults.filledTonalButtonColors(),
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            Text(
                text = emoji,
                modifier = Modifier.size(24.dp),
                textAlign = TextAlign.Center,
            )
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = value,
                    style = MaterialTheme.typography.labelMedium,
                    color = MaterialTheme.colorScheme.primary,
                )
                Text(
                    text = label,
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        }
    }
}

private fun formatMinutes(totalMinutes: Int): String {
    val hours = totalMinutes / 60
    val minutes = totalMinutes % 60
    return if (hours > 0) "${hours}h ${minutes}m" else "${minutes}m"
}
