package dev.creapolis.pepinillo.presentation

import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.wear.compose.material.Button
import androidx.wear.compose.material.ScalingLazyColumn
import androidx.wear.compose.material.Text
import dev.creapolis.pepinillo.data.WearTask

@Composable
fun TasksScreen(
    tasks: List<WearTask>,
    onCompleteTask: (String) -> Unit,
) {
    ScalingLazyColumn {
        item {
            Text(text = "Tareas (${tasks.size})")
        }

        if (tasks.isEmpty()) {
            item { Text(text = "Sin tareas activas") }
        } else {
            items(tasks.size) { index ->
                val task = tasks[index]
                Button(
                    onClick = { onCompleteTask(task.id) },
                    modifier = Modifier.padding(vertical = 4.dp),
                ) {
                    val progress = if (task.pomodoroProgress.isNotBlank()) " ${task.pomodoroProgress}" else ""
                    Text("${task.energyEmoji} ${task.title}$progress")
                }
            }
        }
    }
}
