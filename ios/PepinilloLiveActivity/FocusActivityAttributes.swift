// FocusActivityAttributes.swift
// Pepinillo — Deep Work Companion for Apple
//
// ActivityKit attributes for Live Activities and Dynamic Island.
// Supports all 4 focus modes with mode-specific display.

import Foundation
import ActivityKit

struct FocusActivityAttributes: ActivityAttributes {
    // Static content (set once when activity starts)
    var startedAt: Date
    var targetDuration: TimeInterval?    // nil for open-ended modes
    var focusMode: String                // FocusMode.rawValue
    var taskName: String?

    // Dynamic content (updated as session progresses)
    public struct ContentState: Codable, Hashable {
        var elapsedSeconds: Int          // always tracked
        var remainingSeconds: Int?       // nil for count-up modes
        var focusMode: String            // redundant but useful for widget rendering
        var phase: String                // "Focus", "Short Break", "Long Break", "Flow", "Block", "Free Focus"
        var taskName: String?
        var progress: Double?            // 0.0–1.0 for countdown modes
        var pomodoroNumber: Int?         // only for Pomodoro: e.g., 3
        var totalPomodoros: Int?         // only for Pomodoro: e.g., 4
        var isPaused: Bool
    }
}

// MARK: - Convenience

extension FocusActivityAttributes {
    /// Create attributes from a session state.
    static func from(state: FocusSessionState) -> FocusActivityAttributes {
        FocusActivityAttributes(
            startedAt: state.startedAt,
            targetDuration: state.targetDuration,
            focusMode: state.mode.rawValue,
            taskName: nil  // Set by caller if task is linked
        )
    }

    /// Create an initial content state snapshot.
    static func initialContent(from state: FocusSessionState) -> ContentState {
        ContentState(
            elapsedSeconds: 0,
            remainingSeconds: state.remainingSeconds.map(Int.init),
            focusMode: state.mode.rawValue,
            phase: state.phase.displayName,
            taskName: nil,
            progress: state.progress,
            pomodoroNumber: state.pomodoroNumber,
            totalPomodoros: nil,  // Set by caller from FocusConfig.pomodorosPerCycle
            isPaused: false
        )
    }
}
