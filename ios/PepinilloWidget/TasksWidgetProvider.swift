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
        .empty
    }

    func snapshot(for configuration: ConfigureTasksWidgetIntent, in context: Context) async -> TasksWidgetEntry {
        context.isPreview ? .empty : await buildEntry(configuration: configuration)
    }

    func timeline(for configuration: ConfigureTasksWidgetIntent, in context: Context) async -> Timeline<TasksWidgetEntry> {
        let now = Date.now
        let entry = await buildEntry(configuration: configuration, now: now)
        // Refresh before any paid-access boundary can become stale.
        let routineRefresh = Calendar.current.date(byAdding: .minute, value: 15, to: now) ?? now
        let nextRefresh = TasksWidgetAccess.nextRefreshDate(now: now, normalRefresh: routineRefresh)
        return Timeline(entries: [entry], policy: .after(nextRefresh))
    }

    // MARK: - Entry Construction

    private func buildEntry(configuration: ConfigureTasksWidgetIntent, now: Date = Date.now) async -> TasksWidgetEntry {
        // Tier split (PRD/04): free gets the daily count, Pro the interactive
        // list. One authorized SwiftData pass serves both.
        let isPro = TasksWidgetAccess.isCurrentUserAuthorized(now: now)
        do {
            guard let container = try TasksWidgetAccess.loadIfAuthorized(now: now, {
                try makeWidgetModelContainer()
            }) else {
                // Unreachable (isPro mirrors the same check) — kept as a
                // type-level safety net for the loadIfAuthorized contract.
                return .empty
            }
            let context = ModelContext(container)

            // Fetch active tasks, then apply the same "Today" semantics used by
            // the Plan screen: explicitly scheduled for today, due today, or overdue.
            // Do not fetch-limit before filtering, otherwise earlier inbox/upcoming
            // tasks can crowd out today's tasks and make the widget look empty.
            var descriptor = FetchDescriptor<TaskItem>(
                predicate: #Predicate<TaskItem> { task in
                    task.isCompleted == false
                        && task.isRecurringTemplate == false
                        && task.isDeleted == false
                },
                sortBy: [
                    SortDescriptor(\.sortOrder),
                    SortDescriptor(\.createdAt, order: .reverse),
                ]
            )
            // Bound the fetch: the widget renders at most 8 tasks. We fetch 50 so
            // the in-memory today/due/overdue filter has enough candidates without
            // scanning the full table.
            descriptor.fetchLimit = 50
            // Avoid loading relationships in widget process
            descriptor.relationshipKeyPathsForPrefetching = []

            let calendar = Calendar.current
            let now = Date.now
            let todayStart = calendar.startOfDay(for: now)
            let todayTasks = try context.fetch(descriptor)
                .filter { task in
                    let isDueToday = task.dueDate.map { calendar.isDateInToday($0) } ?? false
                    let isOverdue = task.dueDate.map { $0 < todayStart } ?? false
                    return task.scheduledForToday || isDueToday || isOverdue
                }
            let tasks = todayTasks.prefix(8)

            let isSessionActive = AppGroupDefaults.isSessionActive
            let activeTaskID = isSessionActive ? AppGroupDefaults.activeTaskID : nil

            if !isPro {
                return TasksWidgetEntry(
                    date: Date.now,
                    tasks: [],
                    activeTaskID: nil,
                    isSessionActive: isSessionActive,
                    isProUser: false,
                    todayTaskCount: todayTasks.count
                )
            }

            let widgetTasks = tasks.map { task in
                TasksWidgetEntry.WidgetTask(
                    id: task.id.uuidString,
                    title: task.title,
                    isCompleted: task.isCompleted,
                    energyIcon: task.energyLevel.icon,
                    completedPomodoros: task.completedPomodoros,
                    estimatedPomodoros: task.estimatedPomodoros,
                    priorityValue: task.priority.rawValue
                )
            }

            return TasksWidgetEntry(
                date: Date.now,
                tasks: Array(widgetTasks),
                activeTaskID: activeTaskID,
                isSessionActive: isSessionActive,
                isProUser: true,
                todayTaskCount: todayTasks.count
            )
        } catch {
            // If an authorized SwiftData fetch fails, return an unlocked empty state.
            return .empty
        }
    }
}
