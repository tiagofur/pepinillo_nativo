// TasksWidgetProvider.swift
// Pepinillo — Deep Work Companion for Apple
//
// Timeline provider for the Tasks widget.
// Reads active tasks from the shared SwiftData store (App Group).

import WidgetKit
import SwiftData
import Foundation

struct TasksWidgetProvider: AppIntentTimelineProvider {
    typealias Entry = TasksWidgetEntry
    typealias Intent = ConfigureTasksWidgetIntent

    func placeholder(in context: Context) -> TasksWidgetEntry {
        .placeholder
    }

    func snapshot(for configuration: ConfigureTasksWidgetIntent, in context: Context) async -> TasksWidgetEntry {
        context.isPreview ? .placeholder : await buildEntry(configuration: configuration)
    }

    func timeline(for configuration: ConfigureTasksWidgetIntent, in context: Context) async -> Timeline<TasksWidgetEntry> {
        let entry = await buildEntry(configuration: configuration)
        let nextRefresh = Calendar.current.date(byAdding: .minute, value: 30, to: Date.now) ?? Date.now
        return Timeline(entries: [entry], policy: .after(nextRefresh))
    }

    // MARK: - Entry Construction

    private func buildEntry(configuration: ConfigureTasksWidgetIntent) async -> TasksWidgetEntry {
        do {
            let container = try makeWidgetModelContainer()
            let context = ModelContext(container)

            // Fetch active (non-completed) tasks, sorted by priority desc then sort order
            var descriptor = FetchDescriptor<TaskItem>(
                predicate: #Predicate { !$0.isCompleted },
                sortBy: [
                    SortDescriptor(\.sortOrder),
                    SortDescriptor(\.createdAt, order: .reverse),
                ]
            )
            descriptor.fetchLimit = 8

            let tasks = try context.fetch(descriptor)

            let activeTaskID = AppGroupDefaults.activeTaskID

            let widgetTasks = tasks.map { task in
                TasksWidgetEntry.WidgetTask(
                    id: task.id.uuidString,
                    title: task.title,
                    isCompleted: task.isCompleted,
                    energyIcon: task.energyLevel.icon,
                    completedPomodoros: task.completedPomodoros,
                    estimatedPomodoros: task.estimatedPomodoros,
                    priorityValue: task.priority.sortValue
                )
            }

            return TasksWidgetEntry(
                date: Date.now,
                tasks: widgetTasks,
                activeTaskID: activeTaskID
            )
        } catch {
            return .empty
        }
    }
}

// MARK: - Priority sort value

private extension TaskPriority {
    var sortValue: Int { rawValue }
}
