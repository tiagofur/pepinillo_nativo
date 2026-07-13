// StartFocusIntent.swift
// Pepinillo — Deep Work Companion for Apple
//
// App Intent for Siri and Shortcuts.
// "Start a Pomodoro in Pepinillo" / "Start deep work in Pepinillo"
// Supports all 4 focus modes, duration, and task selection.
// Localized: EN, ES, PT

import AppIntents
import Foundation
import SwiftData

// MARK: - Start Focus Intent

struct StartFocusIntent: AppIntent {
    static let title: LocalizedStringResource = "Start a Focus Session"
    static let description = IntentDescription(
        "Start a deep work session in Pepinillo with your preferred focus technique.",
        categoryName: "Focus"
    )
    static let openAppWhenRun: Bool = true

    @Parameter(title: "Focus Mode")
    var mode: FocusModeEntity?

    @Parameter(title: "Duration (minutes)")
    var duration: Int?

    @Parameter(title: "Task")
    var task: TaskEntity?

    static var parameterSummary: some ParameterSummary {
        Summary("Start \(\.$mode) session on \(\.$task)")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let modeID = mode?.id ?? AppGroupDefaults.widgetSelectedMode ?? FocusModeEntity.pomodoro.id
        let started = AppGroupDefaults.queueExternalStart(
            modeID: modeID,
            taskID: task?.id
        )

        let modeName = mode?.displayName
            ?? FocusModeEntity(rawValue: modeID)?.displayName
            ?? String(localized: "Focus")

        guard started else {
            return .result(
                dialog: "\(modeName) requires Pepinillo Pro. Open the app to upgrade."
            )
        }

        let taskPart = task.map { " " + String(localized: "working on \($0.title)") } ?? ""
        return .result(dialog: "Started \(modeName) session\(taskPart). Let's focus! 🎯")
    }
}

// MARK: - Stop Focus Intent

struct StopFocusIntent: AppIntent {
    static let title: LocalizedStringResource = "Stop Focus Session"
    static let description = IntentDescription(
        "Stop the current focus session in Pepinillo.",
        categoryName: "Focus"
    )
    static let openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult & ProvidesDialog {
        AppGroupDefaults.queueExternalStop()
        return .result(dialog: "Focus session stopped.")
    }
}

// MARK: - Focus Mode Entity

enum FocusModeEntity: String, AppEnum, CaseIterable {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Focus Mode")

    case pomodoro
    case flowtime
    case timeBlock
    case stopwatch

    static let caseDisplayRepresentations: [FocusModeEntity: DisplayRepresentation] = [
        .pomodoro: DisplayRepresentation(title: "Pomodoro", image: .init(systemName: "timer")),
        .flowtime: DisplayRepresentation(title: "Flowtime", image: .init(systemName: "wind")),
        .timeBlock: DisplayRepresentation(title: "Time Block", image: .init(systemName: "rectangle.split.3x1")),
        .stopwatch: DisplayRepresentation(title: "Stopwatch", image: .init(systemName: "stopwatch"))
    ]

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .pomodoro: return "Pomodoro"
        case .flowtime: return "Flowtime"
        case .timeBlock: return "Time Block"
        case .stopwatch: return "Stopwatch"
        }
    }

    var icon: String {
        switch self {
        case .pomodoro: return "🍅"
        case .flowtime: return "🌊"
        case .timeBlock: return "📦"
        case .stopwatch: return "⏱️"
        }
    }

    var iconSystemName: String {
        switch self {
        case .pomodoro: return "timer"
        case .flowtime: return "wind"
        case .timeBlock: return "rectangle.split.3x1"
        case .stopwatch: return "stopwatch"
        }
    }

    static let allModes: [FocusModeEntity] = allCases
}

struct FocusModeQuery {
    func entities(for identifiers: [String]) async throws -> [FocusModeEntity] {
        let idSet = Set(identifiers)
        return FocusModeEntity.allModes.filter { idSet.contains($0.id) }
    }

    func suggestedEntities() async throws -> [FocusModeEntity] {
        FocusModeEntity.allModes
    }

    func defaultResult() async -> FocusModeEntity? {
        .pomodoro
    }
}

// MARK: - Task Entity

struct TaskEntity: AppEntity {
    static let defaultQuery = TaskEntityQuery()
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Task")

    var id: String
    var title: String
    var isCompleted: Bool

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(title)",
            subtitle: isCompleted ? "Completed" : "",
            image: .init(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
        )
    }
}

struct TaskEntityQuery: EntityStringQuery {

    func entities(for identifiers: [String]) async throws -> [TaskEntity] {
        let allTasks = fetchActiveTasks(limit: nil)
        let idSet = Set(identifiers)
        return allTasks.filter { idSet.contains($0.id) }
    }

    func entities(matching string: String) async throws -> [TaskEntity] {
        let allTasks = fetchActiveTasks(limit: nil)
        let lowered = string.lowercased()
        return allTasks.filter { $0.title.lowercased().contains(lowered) }
    }

    func suggestedEntities() async throws -> [TaskEntity] {
        fetchActiveTasks(limit: 10)
    }

    // MARK: - Private

    private func fetchActiveTasks(limit: Int?) -> [TaskEntity] {
        guard let container = try? makeIntentsModelContainer() else { return [] }
        let context = ModelContext(container)
        var descriptor = FetchDescriptor<TaskItem>(
            predicate: #Predicate { !$0.isCompleted },
            sortBy: [SortDescriptor(\.sortOrder)]
        )
        if let limit { descriptor.fetchLimit = limit }
        guard let tasks = try? context.fetch(descriptor) else { return [] }
        return tasks.map {
            TaskEntity(id: $0.id.uuidString, title: $0.title, isCompleted: $0.isCompleted)
        }
    }
}

// MARK: - Shortcuts Provider

struct PepinilloShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartFocusIntent(),
            phrases: [
                "Start deep work in \(.applicationName)",
                "Start a Pomodoro in \(.applicationName)",
                "Focus time with \(.applicationName)",
                "Start a time block in \(.applicationName)",
                "Start flow mode in \(.applicationName)",
                "Start focusing in \(.applicationName)",
            ],
            shortTitle: "Start Focus",
            systemImageName: "brain.head.profile"
        )
        AppShortcut(
            intent: StopFocusIntent(),
            phrases: [
                "Stop focusing in \(.applicationName)",
                "End focus session in \(.applicationName)",
                "Stop Pomodoro in \(.applicationName)",
            ],
            shortTitle: "Stop Focus",
            systemImageName: "stop.circle"
        )
        AppShortcut(
            intent: CheckStatsIntent(),
            phrases: [
                "How's my focus today in \(.applicationName)",
                "Check my stats in \(.applicationName)",
                "How much did I focus in \(.applicationName)",
            ],
            shortTitle: "Check Stats",
            systemImageName: "chart.bar"
        )
        AppShortcut(
            intent: GetWeeklyReportIntent(),
            phrases: [
                "How was my focus this week in \(.applicationName)",
                "Weekly report in \(.applicationName)",
                "Weekly focus summary in \(.applicationName)",
            ],
            shortTitle: "Weekly Report",
            systemImageName: "calendar.badge.clock"
        )
        AppShortcut(
            intent: GetInsightsIntent(),
            phrases: [
                "Give me focus insights in \(.applicationName)",
                "Focus insights from \(.applicationName)",
                "What are my focus patterns in \(.applicationName)",
            ],
            shortTitle: "Focus Insights",
            systemImageName: "lightbulb"
        )
        AppShortcut(
            intent: GetModeSuggestionIntent(),
            phrases: [
                "What focus mode should I use in \(.applicationName)",
                "Suggest a focus mode in \(.applicationName)",
                "Which mode works best in \(.applicationName)",
            ],
            shortTitle: "Suggest Mode",
            systemImageName: "brain"
        )
        AppShortcut(
            intent: PauseFocusIntent(),
            phrases: [
                "Pause focus in \(.applicationName)",
                "Pause my session in \(.applicationName)",
                "Take a break in \(.applicationName)",
            ],
            shortTitle: "Pause Focus",
            systemImageName: "pause.circle"
        )
        AppShortcut(
            intent: ResumeFocusIntent(),
            phrases: [
                "Resume focus in \(.applicationName)",
                "Continue my session in \(.applicationName)",
                "Resume session in \(.applicationName)",
            ],
            shortTitle: "Resume Focus",
            systemImageName: "play.circle"
        )
        AppShortcut(
            intent: GetCurrentSessionIntent(),
            phrases: [
                "Am I focusing in \(.applicationName)",
                "What's my current session in \(.applicationName)",
                "Is a session active in \(.applicationName)",
            ],
            shortTitle: "Current Session",
            systemImageName: "timer"
        )
    }
}
