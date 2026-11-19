// OpenTaskIntent.swift
// Pepinillo — Deep Work Companion for Apple
//
// App Intent for Siri, Spotlight and the Shortcuts app: "Open a task in
// Pepinillo" (#900). Navigates to the task by riding the existing
// pepinillo://task/<id> deep-link pipeline (no new navigation surface).
// No AppShortcut entry — dynamic-entity phrases are clunky and the
// provider is at Apple's 10-shortcut limit (slot decision A3).
// Localized: EN, ES, PT.

import AppIntents
import Foundation

// MARK: - Open Task Intent

struct OpenTaskIntent: AppIntent {
    static let title: LocalizedStringResource = "Open a Task"
    static let description = IntentDescription(
        "Open a task from your Pepinillo plan in the app.",
        categoryName: "Tasks"
    )
    // The deep link only navigates if the app is up: the system launches
    // the app first, then perform() routes the URL into it.
    static let openAppWhenRun: Bool = true

    @Parameter(title: "Task")
    var task: TaskEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Open \(\.$task)")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let id = UUID(uuidString: task.id),
              let url = TaskIntentService.deepLinkURL(for: id) else {
            return .result(dialog: "I couldn't find that task in Pepinillo.")
        }

        TaskIntentService.open(url)
        return .result(dialog: "Opening \(task.title) in Pepinillo.")
    }
}
