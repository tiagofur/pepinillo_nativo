package dev.creapolis.pepinillo.data

import java.util.Base64

internal object WearSnapshotTaskCodec {
    fun serialize(tasks: List<WearTask>): String =
        tasks.joinToString(separator = "\n") { task ->
            listOf(task.id, task.title, task.energyEmoji, task.pomodoroProgress)
                .joinToString(separator = "|") { value ->
                    Base64.getEncoder().encodeToString(value.toByteArray())
                }
        }

    fun deserialize(tasksJson: String): List<WearTask> =
        runCatching {
            tasksJson
                .lineSequence()
                .filter { it.isNotBlank() }
                .mapNotNull { line ->
                    val parts = line.split('|')
                    if (parts.size != 4) return@mapNotNull null
                    val decoded = parts.map { encoded ->
                        String(Base64.getDecoder().decode(encoded))
                    }
                    WearTask(
                        id = decoded[0],
                        title = decoded[1],
                        energyEmoji = decoded[2],
                        pomodoroProgress = decoded[3],
                    )
                }
                .toList()
        }.getOrDefault(emptyList())
}
