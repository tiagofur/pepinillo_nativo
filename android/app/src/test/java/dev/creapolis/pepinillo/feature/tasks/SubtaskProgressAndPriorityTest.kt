package dev.creapolis.pepinillo.feature.tasks

import dev.creapolis.pepinillo.feature.tasks.model.Task
import dev.creapolis.pepinillo.feature.tasks.model.TaskPriority
import org.junit.Assert.assertEquals
import org.junit.Test

class SubtaskProgressAndPriorityTest {

    @Test
    fun tasksUiState_holdsSubtaskProgressMap() {
        val map = mapOf("task-1" to Pair(2, 5), "task-2" to Pair(0, 3))
        val state = TasksUiState(
            subtaskProgressMap = map,
        )
        assertEquals(2, state.subtaskProgressMap.size)
        assertEquals(Pair(2, 5), state.subtaskProgressMap["task-1"])
        assertEquals(Pair(0, 3), state.subtaskProgressMap["task-2"])
    }

    @Test
    fun taskPriorityNone_canBeAssignedToTask() {
        val task = Task(title = "Test Task", priority = TaskPriority.High)
        val clearedTask = task.copy(priority = TaskPriority.None)
        assertEquals(TaskPriority.None, clearedTask.priority)
    }
}
