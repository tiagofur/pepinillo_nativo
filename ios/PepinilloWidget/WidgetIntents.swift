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
        try? refreshDurationsFromSharedStore()
        
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
        guard AppGroupDefaults.requestExternalPause() else {
            return .result()
        }
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
        guard AppGroupDefaults.requestExternalResume() else {
            return .result()
        }
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

// MARK: - Staggered Timeline Math (testable, pure)

/// Computes the (date, progress) snapshots for a live countdown timeline.
/// Pure function so FocusWidgetProviderTests can pin the staggering math
/// without instantiating the provider (which the test target cannot see).
///
/// - Parameters:
///   - start: phase start anchor (progress denominator origin).
///   - now: timeline generation time (first snapshot date).
///   - end: phase end anchor (last snapshot date).
///   - step: seconds between snapshots; `maxEntries` caps long phases.
/// - Returns: snapshots from `now` to `end`, dates strictly advancing,
///   progress climbing 0→1. Empty when `end <= now`.
func staggeredTimelineSnapshots(
    start: Date,
    now: Date,
    end: Date,
    step: TimeInterval = 30,
    maxEntries: Int = 50
) -> [(date: Date, progress: Double)] {
    let total = end.timeIntervalSince(now)
    guard total > 0 else { return [] }
    let count = min(maxEntries, max(2, Int(ceil(total / step)) + 1))
    let duration = max(end.timeIntervalSince(start), 1)
    return (0..<count).map { i in
        // Anchor forward from NOW, not from the phase start: entries dated in
        // the past are discarded by WidgetKit, collapsing the timeline back
        // to a single effective entry (frozen ring).
        let date = i == 0 ? now : min(now.addingTimeInterval(Double(i) * step), end)
        let completed = min(max(date.timeIntervalSince(start) / duration, 0), 1)
        return (date, completed)
    }
}

// MARK: - Start Next Phase from Widget

/// Widget "start next phase" tap during the waiting hold (auto-start OFF).
/// Optimistically clears the hold so the widget switches to the pending
/// phase's live countdown instantly; the app reconciles via
/// `externalNextPhaseRequested` and re-anchors with the true engine time.
struct StartNextPhaseFromWidgetIntent: AppIntent {
    static let title: LocalizedStringResource = "Start Next Phase"
    static let description = IntentDescription("Start the pending phase from the widget.")
    static let openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult {
        guard AppGroupDefaults.isSessionActive, AppGroupDefaults.activeSessionIsWaiting else {
            return .result()
        }
        let now = Date.now
        if let target = AppGroupDefaults.activeSessionNextPhaseTarget, target > 0 {
            AppGroupDefaults.activeSessionTimerStart = now
            AppGroupDefaults.activeSessionTimerEnd = now.addingTimeInterval(target)
            AppGroupDefaults.activeSessionRemaining = target
            AppGroupDefaults.activeSessionProgress = 0
        } else {
            // Open-ended pending phase (flow/block/freeform): no countdown end.
            AppGroupDefaults.activeSessionTimerStart = now
            AppGroupDefaults.activeSessionTimerEnd = nil
            AppGroupDefaults.activeSessionRemaining = nil
            AppGroupDefaults.activeSessionProgress = nil
        }
        AppGroupDefaults.activeSessionElapsed = 0
        AppGroupDefaults.activeSessionNextPhaseTarget = nil
        AppGroupDefaults.activeSessionIsPaused = false
        AppGroupDefaults.activeSessionIsWaiting = false

        AppGroupDefaults.externalCommandID = UUID().uuidString
        AppGroupDefaults.externalCommandIssuedAt = now
        AppGroupDefaults.externalNextPhaseRequested = true
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

// MARK: - Start Focus from Tasks Widget

struct StartFocusFromTasksWidgetIntent: AppIntent {
    static let title: LocalizedStringResource = "Start Focus from Tasks"
    static let description = IntentDescription("Start a focus session from the Tasks widget.")
    static let openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult {
        guard TasksWidgetAccess.isCurrentUserAuthorized() else { return .result() }
        _ = try await StartFocusFromWidgetIntent().perform()
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
        guard TasksWidgetAccess.isCurrentUserAuthorized() else { return .result() }
        let selectedMode = AppGroupDefaults.widgetSelectedMode ?? "pomodoro"
        try? refreshDurationsFromSharedStore()
        let taskTitle = try? Self.taskTitle(for: taskID)
        _ = AppGroupDefaults.queueExternalStart(
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
        var descriptor = FetchDescriptor<TaskItem>(predicate: #Predicate { $0.id == uuid })
        descriptor.fetchLimit = 1
        let tasks = try context.fetch(descriptor)
        return tasks.first?.title
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
        guard let uuid = Self.authorizedTaskID(taskID) else { return .result() }
        // S7: never write SwiftData from the extension process — the app's
        // cached contexts can overwrite it (lost update). Enqueue a completion
        // command instead; the app applies it on next activation. The widget
        // renders the pending command optimistically (see TaskRowInteractive).
        AppGroupDefaults.externalCommandID = UUID().uuidString
        AppGroupDefaults.externalCommandIssuedAt = .now
        AppGroupDefaults.externalCompleteTaskRequested = true
        AppGroupDefaults.externalCompleteTaskID = uuid.uuidString
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }

    static func authorizedTaskID(_ taskID: String, now: Date = Date()) -> UUID? {
        guard TasksWidgetAccess.isCurrentUserAuthorized(now: now) else { return nil }
        return UUID(uuidString: taskID)
    }
}
