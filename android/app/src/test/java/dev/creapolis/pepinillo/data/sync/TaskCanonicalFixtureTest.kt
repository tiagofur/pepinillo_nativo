package dev.creapolis.pepinillo.data.sync

import dev.creapolis.pepinillo.core.network.TaskDto
import kotlinx.serialization.json.Json
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.nio.file.Files
import java.nio.file.Paths

/**
 * Issue #989 (S7): every platform decodes the same canonical wire fixture
 * versioned in the repo (contracts/fixtures/task-canonical-989.json) and
 * asserts the task-model fields survive — this is the Android leg.
 */
class TaskCanonicalFixtureTest {

    @Test
    fun `canonical wire fixture decodes into TaskDto`() {
        val repoRoot = Paths.get(System.getProperty("user.dir"), "..", "..").normalize()
        val fixture = repoRoot.resolve("contracts").resolve("fixtures").resolve("task-canonical-989.json")
        assertTrue("fixture must exist in the repo: $fixture", Files.exists(fixture))

        val json = Json { ignoreUnknownKeys = true }
        val dto = json.decodeFromString(TaskDto.serializer(), Files.readString(fixture))

        assertEquals("fixture-989-canonical", dto.syncId)
        assertNotNull("dueDate must survive the decode", dto.dueDate)
        assertEquals("2026-11-26", dto.dueDate!!.substring(0, 10))
        assertNull("unfinished fixture carries completedAt = NULL", dto.completedAt)
        assertTrue("scheduledForToday must survive the decode", dto.scheduledForToday)
        assertEquals(6, dto.sortOrder)
        assertEquals("shallow", dto.energyLevel)
        assertEquals(5, dto.completedPomodoros)
        assertEquals(2, dto.subTasks?.size)
    }
}
