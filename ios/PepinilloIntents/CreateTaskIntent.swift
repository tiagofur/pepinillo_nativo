// CreateTaskIntent.swift
// Pepinillo — Deep Work Companion for Apple
//
// App Intent for Siri and Shortcuts: "Create a task in Pepinillo".
// Adds a task with title and optional notes without opening the app,
// using the same SwiftData store as the app (intents container).
// Localized: EN, ES, PT.

import AppIntents
import Foundation
import SwiftData
import WidgetKit

// MARK: - Create Task Intent

struct CreateTaskIntent: AppIntent {
    static let title: LocalizedStringResource = "Create a Task"
    static let description = IntentDescription(
        "Add a new task to your Pepinillo plan with a title and optional notes.",
        categoryName: "Tasks"
    )

    @Parameter(title: "Title")
    var taskTitle: String

    @Parameter(title: "Notes")
    var notes: String?

    static var parameterSummary: some ParameterSummary {
        Summary("Create \(\.$taskTitle) with notes \(\.$notes)")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let normalizedTitle = CreateTaskService.normalizedTitle(taskTitle)
        guard !normalizedTitle.isEmpty else {
            return .result(dialog: "Give the task a name first.")
        }
        guard let container = try? makeIntentsModelContainer(),
              CreateTaskService.insertTask(
                  normalizedTitle,
                  notes: CreateTaskService.normalizedNotes(notes),
                  in: container
              ) != nil else {
            return .result(dialog: "Pepinillo couldn't save the task. Open the app and try again.")
        }
        WidgetCenter.shared.reloadAllTimelines()
        return .result(dialog: "Added \(normalizedTitle) to your plan ✅")
    }
}

// MARK: - Creation Service

enum CreateTaskService {

    struct InsertResult: Equatable {
        let sortOrder: Int
    }

    /// Trims surrounding whitespace (Siri dictation often adds it).
    static func normalizedTitle(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Blank notes collapse to nil, matching in-app Quick Capture.
    static func normalizedNotes(_ raw: String?) -> String? {
        guard let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else { return nil }
        return trimmed
    }

    /// Inserts a task at the end of the plan (`sortOrder` = max + 1) with the
    /// same defaults as in-app creation: no priority, deep energy, 1 pomodoro.
    @discardableResult
    static func insertTask(_ title: String, notes: String?, in container: ModelContainer) -> InsertResult? {
        let clean = normalizedTitle(title)
        guard !clean.isEmpty else { return nil }

        let context = ModelContext(container)
        let descriptor = FetchDescriptor<TaskItem>(sortBy: [SortDescriptor(\.sortOrder)])
        let existing = (try? context.fetch(descriptor)) ?? []

        let task = TaskItem(title: clean, notes: notes)
        task.sortOrder = (existing.map(\.sortOrder).max() ?? -1) + 1
        context.insert(task)
        do {
            try context.save()
        } catch {
            return nil
        }
        return InsertResult(sortOrder: task.sortOrder)
    }
}
