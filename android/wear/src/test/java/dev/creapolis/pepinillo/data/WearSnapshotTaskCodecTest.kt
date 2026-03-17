package dev.creapolis.pepinillo.data

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class WearSnapshotTaskCodecTest {

    @Test
    fun `serialize and deserialize preserve snapshot tasks`() {
        val original = listOf(
            WearTask("task-1", "Deep work", "DEEP", "2/4"),
            WearTask("task-2", "Inbox", "ADMIN", ""),
        )

        val decoded = WearSnapshotTaskCodec.deserialize(WearSnapshotTaskCodec.serialize(original))

        assertEquals(original, decoded)
    }

    @Test
    fun `deserialize returns empty list for invalid payload`() {
        assertTrue(WearSnapshotTaskCodec.deserialize("{bad-json}").isEmpty())
    }
}
