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

data class Task(
    val id: String = UUID.randomUUID().toString(),
    val title: String,
    val isCompleted: Boolean = false,
    val energyLevel: EnergyLevel = EnergyLevel.Regular,
    val priority: TaskPriority = TaskPriority.None,
    val estimatedPomodoros: Int = 1,
    val completedPomodoros: Int = 0,
)
