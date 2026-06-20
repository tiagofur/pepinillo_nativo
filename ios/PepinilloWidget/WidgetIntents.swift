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
    static let openAppWhenRun: Bool = false

    @Parameter(title: "Mode ID")
    var modeID: String?

    init() {}

    init(modeID: String?) {
        self.modeID = modeID
    }

    func perform() async throws -> some IntentResult {
        let selectedMode = modeID ?? AppGroupDefaults.widgetSelectedMode ?? "pomodoro"
        let isPro = AppGroupDefaults.isProUser
        try? WidgetPreferencesCache.refreshDurationsFromSharedStore()
        
        // Pro modes: flowtime, timeBlock
        let isProMode = (selectedMode == "flowtime" || selectedMode == "timeBlock")
        
        if isPro || !isProMode {
            AppGroupDefaults.startWidgetSession(modeID: selectedMode)
        } else {
            AppGroupDefaults.externalCommandID = UUID().uuidString
            AppGroupDefaults.externalCommandIssuedAt = .now
            AppGroupDefaults.requestedMode = selectedMode
            AppGroupDefaults.requestedTaskID = nil
            AppGroupDefaults.externalStartRequested = true
        }

        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

// MARK: - Select Focus Mode from Widget

struct SelectFocusModeFromWidgetIntent: AppIntent {
    static let title: LocalizedStringResource = "Select Focus Mode"
    static let description = IntentDescription("Change the selected focus mode in the widget.")
    static let openAppWhenRun: Bool = false

    @Parameter(title: "Mode ID")
    var modeID: String

    init() {}

    init(modeID: String) {
        self.modeID = modeID
    }

    func perform() async throws -> some IntentResult {
        AppGroupDefaults.widgetSelectedMode = modeID
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

// MARK: - Pause Focus from Widget

struct PauseFocusFromWidgetIntent: AppIntent {
    static let title: LocalizedStringResource = "Pause Focus"
    static let description = IntentDescription("Pause the active focus session.")
    static let openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult {
        // No-op during the waiting-for-next-phase hold — the engine has no running
        // timer, so pausing would corrupt state (completed phase at 0 seconds).
        guard AppGroupDefaults.isSessionActive,
              !AppGroupDefaults.activeSessionIsPaused,
              !AppGroupDefaults.activeSessionIsWaiting else {
            return .result()
        }

        // Calculate and freeze remaining/elapsed time before pausing.
        let now = Date.now
        let elapsed = AppGroupDefaults.activeSessionLiveElapsed(at: now)
        let remaining = AppGroupDefaults.activeSessionLiveRemaining(at: now)
        AppGroupDefaults.activeSessionElapsed = elapsed
        AppGroupDefaults.activeSessionRemaining = remaining

        if let remaining {
            let duration = max(elapsed + remaining, 1)
            AppGroupDefaults.activeSessionProgress = min(max(elapsed / duration, 0), 1)
        }

        AppGroupDefaults.externalCommandID = UUID().uuidString
        AppGroupDefaults.externalCommandIssuedAt = now
        AppGroupDefaults.externalResumeRequested = false
        AppGroupDefaults.externalPauseRequested = true
        AppGroupDefaults.activeSessionIsPaused = true
        AppGroupDefaults.activeSessionPausedAt = now
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

// MARK: - Resume Focus from Widget

struct ResumeFocusFromWidgetIntent: AppIntent {
    static let title: LocalizedStringResource = "Resume Focus"
    static let description = IntentDescription("Resume the paused focus session.")
    static let openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult {
        // No-op during the waiting-for-next-phase hold — calling applyExternalResume()
        // during the hold would invoke startTicking() with remainingSeconds == 0 and
        // immediately re-fire phaseComplete(), causing double interval persistence and
        // double pomodoro-number increment.
        guard AppGroupDefaults.isSessionActive,
              AppGroupDefaults.activeSessionIsPaused,
              !AppGroupDefaults.activeSessionIsWaiting else {
            return .result()
        }

        // Recalculate anchors before resuming.
        let now = Date.now
        if let remaining = AppGroupDefaults.activeSessionRemaining {
            let elapsed = AppGroupDefaults.activeSessionElapsed
            let duration = max(elapsed + remaining, 1)
            AppGroupDefaults.activeSessionTimerEnd = now.addingTimeInterval(remaining)
            AppGroupDefaults.activeSessionTimerStart = now.addingTimeInterval(-elapsed)
            AppGroupDefaults.activeSessionProgress = min(max(elapsed / duration, 0), 1)
            AppGroupDefaults.activeSessionRemaining = nil
        } else {
            AppGroupDefaults.activeSessionTimerStart = now.addingTimeInterval(-AppGroupDefaults.activeSessionElapsed)
        }

        AppGroupDefaults.activeSessionElapsed = AppGroupDefaults.activeSessionLiveElapsed(at: now)
        AppGroupDefaults.externalCommandID = UUID().uuidString
        AppGroupDefaults.externalCommandIssuedAt = now
        AppGroupDefaults.externalPauseRequested = false
        AppGroupDefaults.externalResumeRequested = true
        AppGroupDefaults.activeSessionIsPaused = false
        AppGroupDefaults.activeSessionPausedAt = nil
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

// MARK: - Stop Focus from Widget

struct StopFocusFromWidgetIntent: AppIntent {
    static let title: LocalizedStringResource = "Stop Focus"
    static let description = IntentDescription("Stop the active focus session.")
    static let openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult {
        AppGroupDefaults.externalCommandID = UUID().uuidString
        AppGroupDefaults.externalCommandIssuedAt = .now
        AppGroupDefaults.externalPauseRequested = false
        AppGroupDefaults.externalResumeRequested = false
        AppGroupDefaults.externalStopRequested = true
        AppGroupDefaults.clearActiveSession()
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

// MARK: - Start Focus with Task from Widget

struct StartFocusWithTaskIntent: AppIntent {
    static let title: LocalizedStringResource = "Start Focus with Task"
    static let description = IntentDescription("Start a focus session linked to a specific task.")
    static let openAppWhenRun: Bool = false

    @Parameter(title: "Task ID")
    var taskID: String

    init() {}

    init(taskID: String) {
        self.taskID = taskID
    }

    func perform() async throws -> some IntentResult {
        let selectedMode = AppGroupDefaults.widgetSelectedMode ?? "pomodoro"
        try? WidgetPreferencesCache.refreshDurationsFromSharedStore()
        let taskTitle = try? Self.taskTitle(for: taskID)
        AppGroupDefaults.startWidgetSession(
            modeID: selectedMode,
            taskID: taskID,
            taskTitle: taskTitle
        )
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }

    private static func taskTitle(for taskID: String) throws -> String? {
        guard let uuid = UUID(uuidString: taskID) else { return nil }
        let container = try makeWidgetModelContainer()
        let context = ModelContext(container)
        var descriptor = FetchDescriptor<TaskItem>(
            predicate: #Predicate { $0.id == uuid }
        )
        descriptor.fetchLimit = 1
        let tasks = try context.fetch(descriptor)
        return tasks.first?.title
    }
}

private enum WidgetPreferencesCache {
    static func refreshDurationsFromSharedStore() throws {
        let container = try makeWidgetModelContainer()
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<UserPreferences>()
        guard let preferences = try context.fetch(descriptor).first else { return }

        if preferences.pomodoroDuration > 0 {
            AppGroupDefaults.pomodoroDuration = preferences.pomodoroDuration
        }
        if preferences.defaultBlockDuration > 0 {
            AppGroupDefaults.blockDuration = preferences.defaultBlockDuration
        }
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
        var descriptor = FetchDescriptor<TaskItem>(
            predicate: #Predicate { $0.id == uuid }
        )
        descriptor.fetchLimit = 1
        let tasks = try context.fetch(descriptor)
        if let task = tasks.first {
            let now = Date.now
            task.isCompleted = true
            task.completedAt = now
            task.updatedAt = now
            task.isDirty = true
            try context.save()
        }
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}
