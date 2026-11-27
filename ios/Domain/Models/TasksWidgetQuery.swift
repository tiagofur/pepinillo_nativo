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
        // resolver, so the predicate bounds the fetch to rows that could
        // POSSIBLY be today (flag shim, a plan before tomorrow, a due before
        // tomorrow) — every .today row qualifies and far-future rows never
        // crowd the limit (#984's concern, re-verified by the judge in PR-c).
        // The in-memory filter then applies the exact rule.
        let todayStart = calendar.startOfDay(for: now)
        let tomorrowStart = calendar.date(byAdding: .day, value: 1, to: todayStart) ?? now
        // nil plan/due defaults to tomorrowStart → compares false (same trick
        // as the original #984 predicate).
        var descriptor = FetchDescriptor<TaskItem>(
            predicate: #Predicate<TaskItem> { task in
                task.isCompleted == false
                    && task.isRecurringTemplate == false
                    && task.isLocallyDeleted == false
                    && (task.scheduledForToday
                        || (task.plannedDate ?? tomorrowStart) < tomorrowStart
                        || (task.dueDate ?? tomorrowStart) < tomorrowStart)
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
