package dev.creapolis.pepinillo.data

import java.util.Base64

internal data class PendingCommand(
    val path: String,
    val data: ByteArray,
)

internal object WearPendingCommandQueue {
    const val MAX_PENDING_COMMANDS = 40
    private const val TIMER_CMD_PREFIX = "/pepinillo/cmd/timer/"

    fun enqueue(existing: List<PendingCommand>, path: String, data: ByteArray): List<PendingCommand> {
        val newCommand = PendingCommand(path = path, data = data)
        val merged = if (path.startsWith(TIMER_CMD_PREFIX)) {
            // Keep only the latest command per timer path (start/pause/resume/stop/skip).
            existing.filterNot { it.path == path } + newCommand
        } else {
            existing + newCommand
        }
        return merged.takeLast(MAX_PENDING_COMMANDS)
    }

    suspend fun flush(
        existing: List<PendingCommand>,
        nodeIds: List<String>,
        send: suspend (nodeId: String, command: PendingCommand) -> Unit,
    ): List<PendingCommand> {
        if (existing.isEmpty() || nodeIds.isEmpty()) return existing

        val stillPending = mutableListOf<PendingCommand>()
        existing.forEach { command ->
            val sent = runCatching {
                nodeIds.forEach { nodeId -> send(nodeId, command) }
            }.isSuccess
            if (!sent) {
                stillPending += command
            }
        }
        return stillPending
    }

    fun serialize(commands: List<PendingCommand>): String {
        return commands.joinToString(separator = "\n") { command ->
            val payload = Base64.getEncoder().encodeToString(command.data)
            "${command.path}|$payload"
        }
    }

    fun deserialize(serialized: String): List<PendingCommand> = runCatching {
        serialized
            .lineSequence()
            .filter { it.isNotBlank() }
            .mapNotNull { line ->
                val separatorIndex = line.indexOf('|')
                if (separatorIndex <= 0) return@mapNotNull null
                val path = line.substring(0, separatorIndex)
                val payload = line.substring(separatorIndex + 1)
            PendingCommand(
                    path = path,
                    data = Base64.getDecoder().decode(payload),
            )
            }
            .toList()
    }.getOrDefault(emptyList())
}