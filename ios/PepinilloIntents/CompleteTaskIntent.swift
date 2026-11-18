// CompleteTaskIntent.swift
// Pepinillo — Deep Work Companion for Apple
//
// App Intent for Siri and Shortcuts: "Complete a task in Pepinillo" (#900).
// Marks a task done in the same SwiftData store as the app (intents
// container) — the voice half of the task lifecycle started in #899.
// Localized: EN, ES, PT.

import AppIntents
import Foundation
import SwiftData
import WidgetKit

// MARK: - Complete Task Intent

struct CompleteTaskIntent: AppIntent {
    static let title: LocalizedStringResource = "Complete a Task"
    static let description = IntentDescription(
        "Mark a task from your Pepinillo plan as done.",
        categoryName: "Tasks"
    )
    static let openAppWhenRun: Bool = false

    @Parameter(title: "Task")
    var task: TaskEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Complete \(\.$task)")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let container = try? makeIntentsModelContainer() else {
            return .result(dialog: "Pepinillo couldn't update the task. Open the app and try again.")
        }
        guard let id = UUID(uuidString: task.id) else {
            return .result(dialog: "I couldn't find that task in Pepinillo.")
        }

        switch TaskCompletionService.markCompleted(id: id, in: container) {
        case .completed(let title):
            WidgetCenter.shared.reloadAllTimelines()
            return .result(dialog: "Marked \(title) as done ✅")
        case .alreadyCompleted(let title):
            return .result(dialog: "\(title) was already done.")
        case .notFound:
            return .result(dialog: "I couldn't find that task in Pepinillo.")
        case .failed:
            return .result(dialog: "Pepinillo couldn't update the task. Open the app and try again.")
        }
    }
}

// MARK: - Completion Service

enum TaskCompletionService {

    enum CompletionOutcome: Equatable {
        /// Saved — isCompleted + completedAt persisted (carries the title).
        case completed(String)
        /// No mutation — the task was already done (carries the title).
        case alreadyCompleted(String)
        /// Unknown id or tombstoned task.
        case notFound
        /// Persistence failed after a valid fetch.
        case failed
    }

    /// Marks a task complete in one save: isCompleted, completedAt and
    /// updatedAt stamped with the same `now`. Tombstoned tasks read as
    /// unknown — deleted work is not completable. Completing is not
    /// free-tier gated: the #216 cap guards creation, not completion.
    static func markCompleted(
        id: UUID,
        now: Date = .now,
        in container: ModelContainer
    ) -> CompletionOutcome {
        let context = ModelContext(container)
        var descriptor = FetchDescriptor<TaskItem>(
            predicate: #Predicate { $0.id == id && !$0.isLocallyDeleted }
        )
        descriptor.fetchLimit = 1
        guard let task = (try? context.fetch(descriptor))?.first else { return .notFound }
        if task.isCompleted { return .alreadyCompleted(task.title) }

        task.isCompleted = true
        task.completedAt = now
        task.updatedAt = now
        do {
            try context.save()
        } catch {
            return .failed
        }
        return .completed(task.title)
    }
}
