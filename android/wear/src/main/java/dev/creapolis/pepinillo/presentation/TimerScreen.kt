package dev.creapolis.pepinillo.presentation

import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.wear.compose.material.Button
import androidx.wear.compose.material.CircularProgressIndicator
import androidx.wear.compose.material.Column
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
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(8.dp),
    ) {
        Text(
            text = state.phaseLabel,
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
                Button(onClick = onPause, modifier = Modifier.padding(bottom = 6.dp)) {
                    Text("Pausar")
                }
                Button(onClick = onStop) {
                    Text("Stop")
                }
            }

            "Paused" -> {
                Button(onClick = onResume, modifier = Modifier.padding(bottom = 6.dp)) {
                    Text("Reanudar")
                }
                Button(onClick = onStop) {
                    Text("Stop")
                }
            }

            "Disconnected" -> {
                Text(
                    text = "Conecta el telefono",
                    style = MaterialTheme.typography.caption2,
                    textAlign = TextAlign.Center,
                )
            }

            else -> {
                Button(onClick = { onStartMode("Pomodoro") }, modifier = Modifier.padding(bottom = 4.dp)) {
                    Text("Pomodoro")
                }
                Button(onClick = { onStartMode("Flow") }, modifier = Modifier.padding(bottom = 4.dp)) {
                    Text("Flow")
                }
                Button(onClick = { onStartMode("Blocks") }, modifier = Modifier.padding(bottom = 4.dp)) {
                    Text("Blocks")
                }
                Button(onClick = { onStartMode("Chrono") }) {
                    Text("Chrono")
                }
            }
        }
    }
}
