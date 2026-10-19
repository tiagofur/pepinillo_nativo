package dev.creapolis.pepinillo.data

import java.util.Base64

internal data class PendingCommand(
    val path: String,
    val data: ByteArray,
)

/**
 * Outcome of an offline-queue flush: commands that no node accepted stay queued,
 * and the number of commands that only reached a subset of nodes is reported for
 * diagnostics (they are treated as delivered — see [WearPendingCommandQueue.flush]).
 */
internal data class FlushResult(
    val stillPending: List<PendingCommand>,
    val partialDeliveries: Int,
)

internal object WearPendingCommandQueue {
    private const val MAX_PENDING_COMMANDS = 40

    /**
     * Timer paths that should be coalesced: only the most-recent command for each path survives
     * offline queuing. This preserves start→stop ordering without dropping unrelated items (#391).
     *
     * E1: these MUST be the same [WearDataPaths] constants the sender uses — the queue
     * previously hardcoded underscore variants ("/pepinillo/cmd/timer_pause") that never
     * matched the real paths ("/pepinillo/cmd/timer/pause"), so the dedup never fired.
     */
    private val COALESCED_PATHS = setOf(
        WearDataPaths.CMD_TIMER_START,
        WearDataPaths.CMD_TIMER_STOP,
        WearDataPaths.CMD_TIMER_PAUSE,
        WearDataPaths.CMD_TIMER_RESUME,
    )

    fun enqueue(existing: List<PendingCommand>, path: String, data: ByteArray): List<PendingCommand> {
        val incoming = PendingCommand(path = path, data = data)
        val deduplicated = if (path in COALESCED_PATHS) {
            // Drop any earlier queued command for this path — only the latest intent matters.
            existing.filterNot { it.path == path } + incoming
        } else {
            existing + incoming
        }
        return deduplicated.takeLast(MAX_PENDING_COMMANDS)
    }

    /**
     * Attempts delivery of every queued command on each connected node.
     *
     * P2(i): a command accepted by ANY node is considered delivered and dropped — the
     * previous behavior re-queued it for every node on partial failure, replaying it on
     * nodes that had already processed it (duplicate pause/start). Only commands that no
     * node accepted stay queued. [FlushResult.partialDeliveries] counts the commands that
     * reached a subset of nodes so callers can surface a diagnostics warning.
     */
    suspend fun flush(
        existing: List<PendingCommand>,
        nodeIds: List<String>,
        send: suspend (nodeId: String, command: PendingCommand) -> Unit,
    ): FlushResult {
        if (existing.isEmpty() || nodeIds.isEmpty()) return FlushResult(existing, partialDeliveries = 0)

        val stillPending = mutableListOf<PendingCommand>()
        var partialDeliveries = 0
        existing.forEach { command ->
            var acceptedNodes = 0
            nodeIds.forEach { nodeId ->
                if (runCatching { send(nodeId, command) }.isSuccess) {
                    acceptedNodes += 1
                }
            }
            when {
                acceptedNodes == 0 -> stillPending += command
                acceptedNodes < nodeIds.size -> partialDeliveries += 1
            }
        }
        return FlushResult(stillPending, partialDeliveries)
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
