package dev.creapolis.pepinillo.feature.tasks

import dev.creapolis.pepinillo.feature.tasks.model.Task
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.util.Calendar
import java.util.TimeZone

class TaskPlanFilterTest {

    @Test
    fun isUpcomingMs_includesDueBeyondSevenDays() {
        val todayNorm = normalizedToday()
        val dueInTenDays = (todayNorm.clone() as Calendar).apply {
            add(Calendar.DAY_OF_YEAR, 10)
        }.timeInMillis

        assertTrue(isUpcomingMs(dueInTenDays, todayNorm))
    }

    @Test
    fun isUpcomingMs_includesDueWithinSevenDays() {
        val todayNorm = normalizedToday()
        val dueInThreeDays = (todayNorm.clone() as Calendar).apply {
            add(Calendar.DAY_OF_YEAR, 3)
        }.timeInMillis

        assertTrue(isUpcomingMs(dueInThreeDays, todayNorm))
    }

    @Test
    fun isUpcomingMs_excludesDueTodayAndOverdue() {
        val todayNorm = normalizedToday()
        val yesterday = (todayNorm.clone() as Calendar).apply {
            add(Calendar.DAY_OF_YEAR, -1)
        }.timeInMillis

        assertFalse(isUpcomingMs(todayNorm.timeInMillis, todayNorm))
        assertFalse(isUpcomingMs(yesterday, todayNorm))
    }

    @Test
    fun upcomingFilter_includesTaskDueBeyondSevenDays() {
        val todayNorm = normalizedToday()
        val dueInTenDays = (todayNorm.clone() as Calendar).apply {
            add(Calendar.DAY_OF_YEAR, 10)
        }.timeInMillis
        val task = Task(title = "Far future", dueDate = dueInTenDays)

        val filtered = TasksUiState(
            tasks = listOf(task),
            selectedFilter = TaskFilter.Upcoming,
        ).filteredTasks

        assertEquals(listOf(task.id), filtered.map { it.id })
    }

    @Test
    fun everyIncompleteTaskAppearsInExactlyOneActivePlanList() {
        val todayNorm = normalizedToday()
        val tomorrow = (todayNorm.clone() as Calendar).apply {
            add(Calendar.DAY_OF_YEAR, 1)
        }.timeInMillis
        val dueInTenDays = (todayNorm.clone() as Calendar).apply {
            add(Calendar.DAY_OF_YEAR, 10)
        }.timeInMillis
        val yesterday = (todayNorm.clone() as Calendar).apply {
            add(Calendar.DAY_OF_YEAR, -1)
        }.timeInMillis

        val scenarios = listOf(
            Task(id = "inbox", title = "Inbox"),
            Task(id = "scheduled", title = "Scheduled today", scheduledForToday = true),
            Task(id = "due-today", title = "Due today", dueDate = todayNorm.timeInMillis),
            Task(id = "overdue", title = "Overdue", dueDate = yesterday),
            Task(id = "tomorrow", title = "Due tomorrow", dueDate = tomorrow),
            Task(id = "far", title = "Due in 10 days", dueDate = dueInTenDays),
            Task(
                id = "scheduled-far",
                title = "Scheduled today with far due",
                scheduledForToday = true,
                dueDate = dueInTenDays,
            ),
        )

        for (task in scenarios) {
            val activeFilters = TaskFilter.entries.filter { filter ->
                filter != TaskFilter.Completed &&
                    TasksUiState(tasks = listOf(task), selectedFilter = filter).filteredTasks.isNotEmpty()
            }
            assertEquals(
                "Task '${task.title}' should appear in exactly one active list",
                1,
                activeFilters.size,
            )
        }
    }

    private fun normalizedToday(): Calendar {
        val local = Calendar.getInstance()
        return Calendar.getInstance(TimeZone.getTimeZone("UTC")).apply {
            clear()
            set(Calendar.YEAR, local.get(Calendar.YEAR))
            set(Calendar.MONTH, local.get(Calendar.MONTH))
            set(Calendar.DAY_OF_MONTH, local.get(Calendar.DAY_OF_MONTH))
        }
    }
}