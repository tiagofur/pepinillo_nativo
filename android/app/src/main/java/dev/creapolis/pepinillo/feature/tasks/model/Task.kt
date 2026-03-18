package dev.creapolis.pepinillo.feature.tasks.model

import java.util.UUID

enum class EnergyLevel(val label: String) {
    Deep("Deep Work"),
    Regular("Regular"),
    Light("Light"),
}

enum class TaskPriority {
    High,
    Medium,
    Low,
    None,
}

enum class RecurrenceOption(val label: String, val rrule: String?) {
    None("None", null),
    Daily("Daily", "FREQ=DAILY"),
    Weekdays("Weekdays", "FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR"),
    Weekly("Weekly", "FREQ=WEEKLY"),
    Biweekly("Biweekly", "FREQ=WEEKLY;INTERVAL=2"),
    Monthly("Monthly", "FREQ=MONTHLY"),
    ;

    companion object {
        fun fromRrule(rrule: String?): RecurrenceOption =
            entries.firstOrNull { it.rrule == rrule } ?: None
    }
}

data class Subtask(
    val id: String = UUID.randomUUID().toString(),
    val title: String,
    val isCompleted: Boolean = false,
    val sortOrder: Int = 0,
)

data class Task(
    val id: String = UUID.randomUUID().toString(),
    val title: String,
    val notes: String? = null,
    val isCompleted: Boolean = false,
    val completedAt: Long? = null,
    val energyLevel: EnergyLevel = EnergyLevel.Regular,
    val priority: TaskPriority = TaskPriority.None,
    val estimatedPomodoros: Int = 1,
    val completedPomodoros: Int = 0,
    val sortOrder: Int = 0,
    val dueDate: Long? = null,
    val scheduledForToday: Boolean = false,
    val recurrenceRule: String? = null,
    val isRecurringTemplate: Boolean = false,
    val recurringTemplateID: String? = null,
    val createdAt: Long = System.currentTimeMillis(),
)
