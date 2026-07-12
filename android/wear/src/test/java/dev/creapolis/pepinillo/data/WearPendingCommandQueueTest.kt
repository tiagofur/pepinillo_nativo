package dev.creapolis.pepinillo.data

import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * S7 (#391): pending timer commands coalesce per path; non-timer commands are preserved.
 */
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

    @Test
    fun `enqueue coalesces timer commands keeping latest per path`() {
        val start1 = PendingCommand("/pepinillo/cmd/timer/start", "Pomodoro".toByteArray())
        val start2 = PendingCommand("/pepinillo/cmd/timer/start", "Flow".toByteArray())
        val pause1 = PendingCommand("/pepinillo/cmd/timer/pause", byteArrayOf())
        val pause2 = PendingCommand("/pepinillo/cmd/timer/pause", byteArrayOf(1))
        val task = PendingCommand("/pepinillo/cmd/task/complete", "task-1".toByteArray())

        var commands = listOf(start1, pause1, task)
        commands = WearPendingCommandQueue.enqueue(
            existing = commands,
            path = start2.path,
            data = start2.data,
        )
        commands = WearPendingCommandQueue.enqueue(
            existing = commands,
            path = pause2.path,
            data = pause2.data,
        )

        assertEquals(3, commands.size)
        assertEquals("/pepinillo/cmd/task/complete", commands[0].path)
        assertEquals("/pepinillo/cmd/timer/start", commands[1].path)
        assertArrayEquals("Flow".toByteArray(), commands[1].data)
        assertEquals("/pepinillo/cmd/timer/pause", commands[2].path)
        assertArrayEquals(byteArrayOf(1), commands[2].data)
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
    fun `flush keeps commands that fail on any node`() = runBlocking {
        val commands = listOf(
            PendingCommand("/ok", "one".toByteArray()),
            PendingCommand("/fail", "two".toByteArray()),
            PendingCommand("/ok-2", "three".toByteArray()),
        )

        val sent = mutableListOf<String>()
        val remaining = WearPendingCommandQueue.flush(commands, listOf("node-a", "node-b")) { nodeId, command ->
            sent += "$nodeId:${command.path}"
            if (command.path == "/fail") error("boom")
        }

        assertEquals(1, remaining.size)
        assertEquals("/fail", remaining.single().path)
        assertTrue(sent.contains("node-a:/ok"))
        assertTrue(sent.contains("node-b:/ok"))
        assertTrue(sent.contains("node-a:/fail"))
    }
}