package dev.creapolis.pepinillo.presentation

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
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.delay
import androidx.wear.compose.material.Button
import androidx.wear.compose.material.ButtonDefaults
import androidx.wear.compose.material.CircularProgressIndicator
import androidx.wear.compose.material.CompactChip
import androidx.wear.compose.material.MaterialTheme
import androidx.wear.compose.material.Text
import dev.creapolis.pepinillo.data.WearTimerState

@Composable
fun TimerScreen(
    state: WearTimerState,
    pendingCommandCount: Int = 0,
    syncStatusLabel: String? = null,
    isSyncStale: Boolean = false,
    onStartMode: (String) -> Unit,
    onPause: () -> Unit,
    onResume: () -> Unit,
    onStop: () -> Unit,
) {
    val haptics = LocalHapticFeedback.current
    val modeColor = WearModeColors.forMode(state.mode)

    when (state.status) {
        "Running", "Paused" -> TimerActiveLayout(
            state = state,
            modeColor = modeColor,
            onPause = {
                haptics.performHapticFeedback(HapticFeedbackType.LongPress)
                onPause()
            },
            onResume = {
                haptics.performHapticFeedback(HapticFeedbackType.LongPress)
                onResume()
            },
            onStop = {
                haptics.performHapticFeedback(HapticFeedbackType.LongPress)
                onStop()
            },
        )

        "Disconnected" -> DisconnectedLayout(
            pendingCommandCount = pendingCommandCount,
        )

        else -> IdleLayout(
            modeColor = modeColor,
            onStartMode = { mode ->
                haptics.performHapticFeedback(HapticFeedbackType.LongPress)
                onStartMode(mode)
            },
        )
    }
}

@Composable
private fun TimerActiveLayout(
    state: WearTimerState,
    modeColor: androidx.compose.ui.graphics.Color,
    onPause: () -> Unit,
    onResume: () -> Unit,
    onStop: () -> Unit,
) {
    var showStopConfirm by remember { mutableStateOf(false) }

    // Auto-dismiss confirmation after 3 seconds
    if (showStopConfirm) {
        LaunchedEffect(Unit) {
            delay(3_000)
            showStopConfirm = false
        }
    }

    Box(
        modifier = Modifier.fillMaxSize(),
        contentAlignment = Alignment.Center,
    ) {
        // Large progress ring as background
        CircularProgressIndicator(
            progress = state.progress.coerceIn(0f, 1f),
            modifier = Modifier
                .fillMaxSize()
                .padding(8.dp),
            indicatorColor = modeColor,
            trackColor = modeColor.copy(alpha = 0.15f),
            strokeWidth = 6.dp,
        )

        // Center content over the ring
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center,
        ) {
            // Mode label
            Text(
                text = state.mode,
                style = MaterialTheme.typography.caption2,
                color = modeColor,
                textAlign = TextAlign.Center,
            )

            // Timer display
            Text(
                text = state.displayTime,
                fontSize = 32.sp,
                fontWeight = FontWeight.Light,
                color = MaterialTheme.colors.onSurface,
                textAlign = TextAlign.Center,
            )

            // Phase label
            Text(
                text = state.phaseLabel,
                style = MaterialTheme.typography.caption2,
                color = MaterialTheme.colors.onSurfaceVariant,
                textAlign = TextAlign.Center,
            )

            Spacer(modifier = Modifier.height(10.dp))

            // Action buttons
            Row(
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                if (state.status == "Running") {
                    CompactChip(
                        onClick = onPause,
                        label = { Text("Pausar", maxLines = 1) },
                        colors = androidx.wear.compose.material.ChipDefaults.secondaryChipColors(),
                    )
                } else {
                    CompactChip(
                        onClick = onResume,
                        label = { Text("Reanudar", maxLines = 1) },
                        colors = androidx.wear.compose.material.ChipDefaults.primaryChipColors(),
                    )
                }
                CompactChip(
                    onClick = {
                        if (showStopConfirm) {
                            showStopConfirm = false
                            onStop()
                        } else {
                            showStopConfirm = true
                        }
                    },
                    label = {
                        Text(
                            text = if (showStopConfirm) "¿Seguro?" else "Detener",
                            maxLines = 1,
                        )
                    },
                    colors = if (showStopConfirm) {
                        androidx.wear.compose.material.ChipDefaults.chipColors(
                            backgroundColor = Color(0xFFB71C1C).copy(alpha = 0.7f),
                            contentColor = Color.White,
                        )
                    } else {
                        androidx.wear.compose.material.ChipDefaults.secondaryChipColors()
                    },
                )
            }
        }

    }
}

@Composable
private fun DisconnectedLayout(
    pendingCommandCount: Int,
) {
    Box(
        modifier = Modifier.fillMaxSize(),
        contentAlignment = Alignment.Center,
    ) {
        // Subtle indeterminate ring
        CircularProgressIndicator(
            modifier = Modifier
                .fillMaxSize()
                .padding(8.dp),
            indicatorColor = MaterialTheme.colors.onSurfaceVariant.copy(alpha = 0.3f),
            trackColor = MaterialTheme.colors.onSurfaceVariant.copy(alpha = 0.08f),
            strokeWidth = 4.dp,
        )

        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center,
            modifier = Modifier.padding(horizontal = 24.dp),
        ) {
            Text(
                text = "📱",
                fontSize = 28.sp,
                textAlign = TextAlign.Center,
            )
            Spacer(modifier = Modifier.height(8.dp))
            Text(
                text = "Conectando con el teléfono",
                style = MaterialTheme.typography.body2,
                color = MaterialTheme.colors.onSurface,
                textAlign = TextAlign.Center,
            )
            if (pendingCommandCount > 0) {
                Spacer(modifier = Modifier.height(4.dp))
                Text(
                    text = "$pendingCommandCount en cola",
                    style = MaterialTheme.typography.caption2,
                    color = MaterialTheme.colors.onSurfaceVariant,
                    textAlign = TextAlign.Center,
                )
            }
        }
    }
}

@Composable
private fun IdleLayout(
    modeColor: androidx.compose.ui.graphics.Color,
    onStartMode: (String) -> Unit,
) {
    Box(
        modifier = Modifier.fillMaxSize(),
        contentAlignment = Alignment.Center,
    ) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center,
            modifier = Modifier.padding(horizontal = 16.dp),
        ) {
            Text(
                text = "Iniciar",
                style = MaterialTheme.typography.title3,
                color = MaterialTheme.colors.onSurface,
                textAlign = TextAlign.Center,
            )

            Spacer(modifier = Modifier.height(8.dp))

            // Mode buttons in 2x2 grid
            Row(
                horizontalArrangement = Arrangement.spacedBy(6.dp),
                modifier = Modifier.fillMaxWidth(),
            ) {
                ModeButton(
                    label = "Pomodoro",
                    color = WearModeColors.Pomodoro,
                    onClick = { onStartMode("Pomodoro") },
                    modifier = Modifier.weight(1f),
                )
                ModeButton(
                    label = "Flow",
                    color = WearModeColors.Flow,
                    onClick = { onStartMode("Flow") },
                    modifier = Modifier.weight(1f),
                )
            }

            Spacer(modifier = Modifier.height(6.dp))

            Row(
                horizontalArrangement = Arrangement.spacedBy(6.dp),
                modifier = Modifier.fillMaxWidth(),
            ) {
                ModeButton(
                    label = "Blocks",
                    color = WearModeColors.Blocks,
                    onClick = { onStartMode("Blocks") },
                    modifier = Modifier.weight(1f),
                )
                ModeButton(
                    label = "Chrono",
                    color = WearModeColors.Chrono,
                    onClick = { onStartMode("Chrono") },
                    modifier = Modifier.weight(1f),
                )
            }
        }

    }
}

@Composable
private fun ModeButton(
    label: String,
    color: androidx.compose.ui.graphics.Color,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Button(
        onClick = onClick,
        modifier = modifier.height(36.dp),
        colors = ButtonDefaults.buttonColors(
            backgroundColor = color.copy(alpha = 0.2f),
            contentColor = color,
        ),
    ) {
        Text(
            text = label,
            style = MaterialTheme.typography.caption2,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
        )
    }
}
