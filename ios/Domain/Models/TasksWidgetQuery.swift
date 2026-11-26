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
        // Issue #984: the today filter lives IN the predicate (with captured
        // day boundaries) so the fetch limit bounds only today-relevant rows —
        // a fetch limit applied before the in-memory filter let 50+ earlier
        // inbox/upcoming tasks crowd today's tasks out of the widget.
        let todayStart = calendar.startOfDay(for: now)
        let tomorrowStart = calendar.date(byAdding: .day, value: 1, to: todayStart) ?? now
        var descriptor = FetchDescriptor<TaskItem>(
            predicate: #Predicate<TaskItem> { task in
                task.isCompleted == false
                    && task.isRecurringTemplate == false
                    && task.isLocallyDeleted == false
                    && (task.scheduledForToday
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

        // Belt and suspenders: the in-memory filter mirrors the predicate
        // (calendar.isDateInToday covers any same-day due timestamp whose
        // instant encoding differs from the captured boundary).
        return try context.fetch(descriptor).filter { task in
            let isDueToday = task.dueDate.map { calendar.isDateInToday($0) } ?? false
            let isOverdue = task.dueDate.map { $0 < todayStart } ?? false
            return task.scheduledForToday || isDueToday || isOverdue
        }
    }
}
