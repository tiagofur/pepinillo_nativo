package dev.creapolis.pepinillo.presentation

import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.Column
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.Alignment
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.wear.compose.material.Button
import androidx.wear.compose.material.CircularProgressIndicator
import androidx.wear.compose.material.MaterialTheme
import androidx.wear.compose.material.Text
import dev.creapolis.pepinillo.data.WearTimerState

@Composable
fun TimerScreen(
    state: WearTimerState,
    onStartMode: (String) -> Unit,
    onPause: () -> Unit,
    onResume: () -> Unit,
    onStop: () -> Unit,
) {
    val haptics = LocalHapticFeedback.current

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(8.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text(
            text = "${state.mode} • ${state.phaseLabel}",
            style = MaterialTheme.typography.caption2,
            textAlign = TextAlign.Center,
            modifier = Modifier.padding(bottom = 4.dp),
        )

        CircularProgressIndicator(
            progress = state.progress.coerceIn(0f, 1f),
            modifier = Modifier.padding(8.dp),
        )

        Text(
            text = state.displayTime,
            fontSize = 30.sp,
            textAlign = TextAlign.Center,
            modifier = Modifier.padding(bottom = 8.dp),
        )

        when (state.status) {
            "Running" -> {
                Button(
                    onClick = {
                        haptics.performHapticFeedback(HapticFeedbackType.LongPress)
                        onPause()
                    },
                    modifier = Modifier.padding(bottom = 6.dp),
                ) {
                    Text("Pausar")
                }
                Button(onClick = {
                    haptics.performHapticFeedback(HapticFeedbackType.LongPress)
                    onStop()
                }) {
                    Text("Detener")
                }
            }

            "Paused" -> {
                Button(
                    onClick = {
                        haptics.performHapticFeedback(HapticFeedbackType.LongPress)
                        onResume()
                    },
                    modifier = Modifier.padding(bottom = 6.dp),
                ) {
                    Text("Reanudar")
                }
                Button(onClick = {
                    haptics.performHapticFeedback(HapticFeedbackType.LongPress)
                    onStop()
                }) {
                    Text("Detener")
                }
            }

            "Disconnected" -> {
                Text(
                    text = "Conecta el telefono para sincronizar",
                    style = MaterialTheme.typography.caption2,
                    textAlign = TextAlign.Center,
                )
            }

            else -> {
                Button(onClick = {
                    haptics.performHapticFeedback(HapticFeedbackType.LongPress)
                    onStartMode("Pomodoro")
                }, modifier = Modifier.padding(bottom = 4.dp)) {
                    Text("Pomodoro")
                }
                Button(onClick = {
                    haptics.performHapticFeedback(HapticFeedbackType.LongPress)
                    onStartMode("Flow")
                }, modifier = Modifier.padding(bottom = 4.dp)) {
                    Text("Flow")
                }
                Button(onClick = {
                    haptics.performHapticFeedback(HapticFeedbackType.LongPress)
                    onStartMode("Blocks")
                }, modifier = Modifier.padding(bottom = 4.dp)) {
                    Text("Blocks")
                }
                Button(onClick = {
                    haptics.performHapticFeedback(HapticFeedbackType.LongPress)
                    onStartMode("Chrono")
                }) {
                    Text("Chrono")
                }
            }
        }
    }
}
