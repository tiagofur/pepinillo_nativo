package dev.creapolis.pepinillo.widget

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Test

class CompleteTaskWorkerTest {

    @Test
    fun `unique work name is per task id`() {
        val nameA = CompleteTaskWorker.uniqueWorkName("task-a")
        val nameB = CompleteTaskWorker.uniqueWorkName("task-b")
        assertEquals("complete_task_task-a", nameA)
        assertEquals("complete_task_task-b", nameB)
        assertNotEquals(nameA, nameB)
    }

    @Test
    fun `unique work name is stable for same task`() {
        assertEquals(
            CompleteTaskWorker.uniqueWorkName("task-1"),
            CompleteTaskWorker.uniqueWorkName("task-1"),
        )
    }
}