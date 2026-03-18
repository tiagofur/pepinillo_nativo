// PauseFocusIntent.swift
// Pepinillo — Deep Work Companion for Apple
//
// App Intent for Siri and Shortcuts: pause/resume the current focus session.

import AppIntents
import Foundation

// MARK: - Pause Focus Intent

struct PauseFocusIntent: AppIntent {
    static let title: LocalizedStringResource = "Pause Focus Session"
    static let description = IntentDescription(
        "Pause the current focus session in Pepinillo.",
        categoryName: "Focus"
    )
    static let openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard AppGroupDefaults.isSessionActive else {
            return .result(dialog: "No focus session is running right now.")
        }

        AppGroupDefaults.externalPauseRequested = true
        return .result(dialog: "Focus session paused. Take a moment.")
    }
}

// MARK: - Resume Focus Intent

struct ResumeFocusIntent: AppIntent {
    static let title: LocalizedStringResource = "Resume Focus Session"
    static let description = IntentDescription(
        "Resume a paused focus session in Pepinillo.",
        categoryName: "Focus"
    )
    static let openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard AppGroupDefaults.isSessionActive else {
            return .result(dialog: "No focus session to resume.")
        }

        AppGroupDefaults.externalResumeRequested = true
        return .result(dialog: "Focus session resumed. Let's go! 🎯")
    }
}

// MARK: - Get Current Session Intent

struct GetCurrentSessionIntent: AppIntent {
    static let title: LocalizedStringResource = "Get Current Focus Session"
    static let description = IntentDescription(
        "Check if a focus session is currently active in Pepinillo.",
        categoryName: "Focus"
    )
    static let openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let defaults = UserDefaults(suiteName: AppGroup.id)
        let isActive = defaults?.bool(forKey: "isSessionActive") ?? false

        guard isActive else {
            return .result(dialog: "No focus session is running. Ready to start one?")
        }

        let modeRaw = defaults?.string(forKey: "activeModeName") ?? "focus"
        let mode: String
        switch modeRaw {
        case "pomodoro":  mode = String(localized: "Pomodoro")
        case "flowtime":  mode = String(localized: "Flowtime")
        case "timeBlock": mode = String(localized: "Time Block")
        case "stopwatch": mode = String(localized: "Stopwatch")
        default:          mode = String(localized: "Focus")
        }
        let elapsed = defaults?.integer(forKey: "activeSessionElapsed") ?? 0
        let minutes = elapsed / 60

        if minutes > 0 {
            return .result(dialog: "You're in a \(mode) session — \(minutes) minutes in. Keep going! 💪")
        }
        return .result(dialog: "You're in a \(mode) session. Stay focused! 🎯")
    }
}
