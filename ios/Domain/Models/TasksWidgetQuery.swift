// TasksWidgetQuery.swift
// Pepinillo — Deep Work Companion for Apple
//
// Shared seam for the Tasks widget's store query (#983): the exact
// predicate, sort and fetch the home-screen Tasks widget runs against the
// App Group store. Extracted verbatim from TasksWidgetProvider so a test
// can execute the real fetch — a #Predicate that references a property
// outside the SwiftData schema crashes with an uncatchable trap that no
// provider-level `catch` can intercept.

import Foundation
import SwiftData

enum TasksWidgetQuery {
    /// Active tasks relevant to "today": explicitly scheduled for today, due
    /// today, or overdue — the same semantics as the Plan screen's Today
    /// filter, in the widget's display order.
    static func todayTasks(
        in container: ModelContainer,
        now: Date = .now,
        calendar: Calendar = .current
    ) throws -> [TaskItem] {
        let context = ModelContext(container)
        // Issue #991 (S7): the widget reads the SAME unified «Hoy» rule as the
        // app — TaskPlanning.bucket (planned ≤ today keeps postponed tasks
        // visible; future plans stay out). SwiftData predicates can't call the
        // resolver, so the predicate fetches every candidate that MIGHT be in
        // today (any plan, any flag, any due) and the in-memory filter applies
        // the exact rule. Issue #984's concern stands: the fetch limit only
        // bounds candidate rows, never today's own.
        var descriptor = FetchDescriptor<TaskItem>(
            predicate: #Predicate<TaskItem> { task in
                task.isCompleted == false
                    && task.isRecurringTemplate == false
                    && task.isLocallyDeleted == false
                    && (task.scheduledForToday
                        || task.plannedDate != nil
                        || task.dueDate != nil)
            },
            sortBy: [
                SortDescriptor(\.sortOrder),
                SortDescriptor(\.createdAt, order: .reverse),
            ]
        )
        // Bound the fetch AFTER the predicate: the widget renders at most 8.
        descriptor.fetchLimit = 50
        // Avoid loading relationships in widget process
        descriptor.relationshipKeyPathsForPrefetching = []

        return try context.fetch(descriptor).filter { task in
            if case .today = TaskPlanning.bucket(
                plannedDate: task.plannedDate,
                dueDate: task.dueDate,
                scheduledForToday: task.scheduledForToday,
                isCompleted: task.isCompleted,
                now: now,
                calendar: calendar
            ) {
                return true
            }
            return false
        }
    }
}
