// GetTodayTasksIntent.swift
// Pepinillo — Deep Work Companion for Apple
//
// App Intent for Siri and Shortcuts: "What are my tasks today in Pepinillo?"
// (#900). Returns today's scheduled active tasks as value + spoken summary.
// Localized: EN, ES, PT.

import AppIntents
import Foundation
import SwiftData

// MARK: - Today's Tasks Intent

struct GetTodayTasksIntent: AppIntent {
    static let title: LocalizedStringResource = "Today's Tasks"
    static let description = IntentDescription(
        "Ask Pepinillo what tasks you planned for today.",
        categoryName: "Tasks"
    )
    static let openAppWhenRun: Bool = false

    func perform() async throws -> some ReturnsValue<[TaskEntity]> & ProvidesDialog {
        guard let container = try? makeIntentsModelContainer() else {
            return .result(value: [], dialog: "I couldn't access your tasks right now.")
        }

        let entities = TaskIntentService.todayTasks(in: container).map {
            TaskEntity(id: $0.id.uuidString, title: $0.title, isCompleted: $0.isCompleted)
        }
        return .result(value: entities, dialog: "\(TodayTasksService.summary(for: entities))")
    }
}

// MARK: - Summary Service

enum TodayTasksService {

    /// Spoken summary: celebratory empty state, every name up to `maxListed`,
    /// then a remainder count. Plain `String` fragments localized per the
    /// CheckStatsIntent pattern — Siri reads the joined result.
    static func summary(for tasks: [TaskEntity], maxListed: Int = 5) -> String {
        guard !tasks.isEmpty else {
            return String(localized: "No tasks scheduled for today 🎉")
        }

        let names = tasks.prefix(maxListed).map(\.title).joined(separator: ", ")
        let rest = tasks.count - min(maxListed, tasks.count)
        if rest > 0 {
            return String(localized: "You have \(tasks.count) for today: \(names) and \(rest) more.")
        }
        return String(localized: "You have \(tasks.count) for today: \(names)")
    }
}
