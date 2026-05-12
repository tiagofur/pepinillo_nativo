// WidgetIntents.swift
// Pepinillo — Deep Work Companion for Apple
//
// App Intents for interactive widget buttons (iOS 17+).
// These run in the widget extension process and communicate
// with the main app via App Group UserDefaults.

import AppIntents
import Foundation
import SwiftData
import WidgetKit

// MARK: - Start Focus from Widget

struct StartFocusFromWidgetIntent: AppIntent {
    static let title: LocalizedStringResource = "Start Focus"
    static let description = IntentDescription("Start a focus session from the widget.")
    static let openAppWhenRun: Bool = true

    @Parameter(title: "Mode ID")
    var modeID: String?

    init() {}

    init(modeID: String?) {
        self.modeID = modeID
    }

    func perform() async throws -> some IntentResult {
        AppGroupDefaults.requestedMode = modeID
        AppGroupDefaults.externalStartRequested = true

        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

// MARK: - Pause Focus from Widget

struct PauseFocusFromWidgetIntent: AppIntent {
    static let title: LocalizedStringResource = "Pause Focus"
    static let description = IntentDescription("Pause the active focus session.")
    static let openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        // Calculate and freeze remaining/elapsed time before pausing
        if let start = AppGroupDefaults.activeSessionTimerStart {
            let now = Date.now
            AppGroupDefaults.activeSessionElapsed = now.timeIntervalSince(start)
            
            if let end = AppGroupDefaults.activeSessionTimerEnd {
                AppGroupDefaults.activeSessionRemaining = max(0, end.timeIntervalSince(now))
            }
        }
        
        AppGroupDefaults.externalPauseRequested = true
        AppGroupDefaults.activeSessionIsPaused = true
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

// MARK: - Resume Focus from Widget

struct ResumeFocusFromWidgetIntent: AppIntent {
    static let title: LocalizedStringResource = "Resume Focus"
    static let description = IntentDescription("Resume the paused focus session.")
    static let openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        // Recalculate anchors before resuming
        if let remaining = AppGroupDefaults.activeSessionRemaining {
            AppGroupDefaults.activeSessionTimerEnd = Date.now.addingTimeInterval(remaining)
            AppGroupDefaults.activeSessionTimerStart = Date.now.addingTimeInterval(-AppGroupDefaults.activeSessionElapsed)
        }
        
        AppGroupDefaults.externalResumeRequested = true
        AppGroupDefaults.activeSessionIsPaused = false
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

// MARK: - Stop Focus from Widget

struct StopFocusFromWidgetIntent: AppIntent {
    static let title: LocalizedStringResource = "Stop Focus"
    static let description = IntentDescription("Stop the active focus session.")
    static let openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        AppGroupDefaults.externalStopRequested = true
        AppGroupDefaults.isSessionActive = false
        AppGroupDefaults.activeSessionIsPaused = false
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

// MARK: - Start Focus with Task from Widget

struct StartFocusWithTaskIntent: AppIntent {
    static let title: LocalizedStringResource = "Start Focus with Task"
    static let description = IntentDescription("Start a focus session linked to a specific task.")
    static let openAppWhenRun: Bool = true

    @Parameter(title: "Task ID")
    var taskID: String

    init() {}

    init(taskID: String) {
        self.taskID = taskID
    }

    func perform() async throws -> some IntentResult {
        AppGroupDefaults.externalStartRequested = true
        AppGroupDefaults.requestedTaskID = taskID
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

// MARK: - Complete Task from Widget

struct CompleteTaskFromWidgetIntent: AppIntent {
    static let title: LocalizedStringResource = "Complete Task"
    static let description = IntentDescription("Mark a task as completed from the widget.")
    static let openAppWhenRun: Bool = false

    @Parameter(title: "Task ID")
    var taskID: String

    init() {}

    init(taskID: String) {
        self.taskID = taskID
    }

    func perform() async throws -> some IntentResult {
        guard let uuid = UUID(uuidString: taskID) else { return .result() }
        let container = try makeWidgetModelContainer()
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<TaskItem>()
        let tasks = try context.fetch(descriptor)
        if let task = tasks.first(where: { $0.id == uuid }) {
            task.isCompleted = true
            task.completedAt = Date.now
            try context.save()
        }
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}
