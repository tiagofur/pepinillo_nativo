package dev.creapolis.pepinillo.data

import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class WearPendingCommandQueueTest {

    @Test
    fun `enqueue keeps only the most recent 40 commands`() {
        var commands = emptyList<PendingCommand>()

        repeat(45) { index ->
            commands = WearPendingCommandQueue.enqueue(
                existing = commands,
                path = "/cmd/$index",
                data = index.toString().toByteArray(),
            )
        }

        assertEquals(40, commands.size)
        assertEquals("/cmd/5", commands.first().path)
        assertEquals("/cmd/44", commands.last().path)
    }

    // ── E1: offline coalescing must key on the real WearDataPaths command paths ──

    @Test
    fun `enqueue coalesces repeated CMD_TIMER_PAUSE commands keeping only the latest`() {
        var commands = WearPendingCommandQueue.enqueue(
            existing = emptyList(),
            path = WearDataPaths.CMD_TIMER_PAUSE,
            data = "older".toByteArray(),
        )
        commands = WearPendingCommandQueue.enqueue(
            existing = commands,
            path = WearDataPaths.CMD_TIMER_PAUSE,
            data = "newer".toByteArray(),
        )

        assertEquals(1, commands.size)
        assertEquals(WearDataPaths.CMD_TIMER_PAUSE, commands.single().path)
        assertArrayEquals("newer".toByteArray(), commands.single().data)
    }

    @Test
    fun `enqueue coalesces every timer command path from WearDataPaths`() {
        val timerPaths = listOf(
            WearDataPaths.CMD_TIMER_START,
            WearDataPaths.CMD_TIMER_STOP,
            WearDataPaths.CMD_TIMER_PAUSE,
            WearDataPaths.CMD_TIMER_RESUME,
        )
        timerPaths.forEach { path ->
            val once = WearPendingCommandQueue.enqueue(
                existing = emptyList(),
                path = path,
                data = "older".toByteArray(),
            )
            val twice = WearPendingCommandQueue.enqueue(
                existing = once,
                path = path,
                data = "latest".toByteArray(),
            )

            assertEquals("expected coalescing for $path", 1, twice.size)
            assertArrayEquals("latest".toByteArray(), twice.single().data)
        }
    }

    @Test
    fun `enqueue keeps duplicate task commands uncoalesced`() {
        val once = WearPendingCommandQueue.enqueue(
            existing = emptyList(),
            path = WearDataPaths.CMD_TASK_COMPLETE,
            data = "task-1".toByteArray(),
        )
        val twice = WearPendingCommandQueue.enqueue(
            existing = once,
            path = WearDataPaths.CMD_TASK_COMPLETE,
            data = "task-2".toByteArray(),
        )

        // Task completions are NOT coalesced — dropping one would lose a user action.
        assertEquals(2, twice.size)
    }

    @Test
    fun `serialize and deserialize preserve command payloads`() {
        val original = listOf(
            PendingCommand("/timer/start", "Pomodoro".toByteArray()),
            PendingCommand("/task/complete", byteArrayOf(1, 2, 3)),
        )

        val decoded = WearPendingCommandQueue.deserialize(
            WearPendingCommandQueue.serialize(original),
        )

        assertEquals(2, decoded.size)
        assertEquals(original[0].path, decoded[0].path)
        assertArrayEquals(original[0].data, decoded[0].data)
        assertEquals(original[1].path, decoded[1].path)
        assertArrayEquals(original[1].data, decoded[1].data)
    }

    @Test
    fun `flush keeps commands that fail on every node`() = runBlocking {
        val commands = listOf(
            PendingCommand("/ok", "one".toByteArray()),
            PendingCommand("/fail", "two".toByteArray()),
            PendingCommand("/ok-2", "three".toByteArray()),
        )

        val sent = mutableListOf<String>()
        val result = WearPendingCommandQueue.flush(commands, listOf("node-a", "node-b")) { nodeId, command ->
            sent += "$nodeId:${command.path}"
            if (command.path == "/fail") error("boom")
        }

        assertEquals(1, result.stillPending.size)
        assertEquals("/fail", result.stillPending.single().path)
        assertTrue(sent.contains("node-a:/ok"))
        assertTrue(sent.contains("node-b:/ok"))
        assertTrue(sent.contains("node-a:/fail"))
    }

    // ── P2(i): a command accepted by any node must not be retried on nodes that already got it ──

    @Test
    fun `flush drops a command once any node accepted it`() = runBlocking {
        val commands = listOf(
            PendingCommand(WearDataPaths.CMD_TIMER_PAUSE, "p".toByteArray()),
        )

        val sent = mutableListOf<String>()
        val result = WearPendingCommandQueue.flush(commands, listOf("node-a", "node-b")) { nodeId, command ->
            sent += "$nodeId:${command.path}"
            if (nodeId == "node-b") error("unreachable")
        }

        // node-a accepted the command: it is delivered. Retrying later would replay it
        // on node-a (duplicate pause/start). Only the count of partial deliveries is kept
        // for diagnostics.
        assertTrue(result.stillPending.isEmpty())
        assertEquals(1, result.partialDeliveries)
        assertEquals(
            listOf("node-a:${WearDataPaths.CMD_TIMER_PAUSE}", "node-b:${WearDataPaths.CMD_TIMER_PAUSE}"),
            sent,
        )
    }
}