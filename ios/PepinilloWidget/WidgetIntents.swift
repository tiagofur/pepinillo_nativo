// WidgetIntents.swift
// Pepinillo — Deep Work Companion for Apple
//
// App Intents for interactive widget buttons (iOS 17+).
// These run in the widget extension process and communicate
// with the main app via App Group UserDefaults.

import AppIntents
import WidgetKit

// MARK: - Start Focus from Widget

struct StartFocusFromWidgetIntent: AppIntent {
    static let title: LocalizedStringResource = "Start Focus"
    static let description = IntentDescription("Start a focus session from the widget.")
    static let openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        AppGroupDefaults.externalStartRequested = true
        AppGroupDefaults.isSessionActive = true
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

// MARK: - Pause Focus from Widget

struct PauseFocusFromWidgetIntent: AppIntent {
    static let title: LocalizedStringResource = "Pause Focus"
    static let description = IntentDescription("Pause or resume the active focus session.")
    static let openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        AppGroupDefaults.externalPauseRequested = true
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
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}
