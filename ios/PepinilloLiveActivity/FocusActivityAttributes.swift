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
        /// Phase anchor for Text(timerInterval:) live countdown/count-up while backgrounded.
        var timerStart: Date?
        /// Countdown end anchor; nil for count-up modes.
        var timerEnd: Date?
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

    /// Create an initial content state snapshot from the live session.
    static func initialContent(from state: FocusSessionState) -> ContentState {
        contentState(from: state, taskName: nil)
    }

    /// Build dynamic content for start/update, including timer anchors for system-driven ticks.
    static func contentState(
        from state: FocusSessionState,
        taskName: String?,
        now: Date = .now
    ) -> ContentState {
        let anchors = timerAnchors(from: state, now: now)
        return ContentState(
            elapsedSeconds: Int(state.elapsedSeconds),
            remainingSeconds: state.remainingSeconds.map(Int.init),
            focusMode: state.mode.rawValue,
            phase: state.phase.displayName,
            taskName: taskName,
            progress: state.progress,
            pomodoroNumber: state.pomodoroNumber,
            totalPomodoros: state.totalPomodoros,
            isPaused: state.isPaused,
            timerStart: anchors.start,
            timerEnd: anchors.end
        )
    }

    /// Compute timer anchors so Live Activity views can use Text(timerInterval:) off-process.
    static func timerAnchors(
        from state: FocusSessionState,
        now: Date = .now
    ) -> (start: Date?, end: Date?) {
        guard !state.isPaused else { return (nil, nil) }

        switch state.mode.direction {
        case .countDown:
            guard let remaining = state.remainingSeconds else { return (nil, nil) }
            let end = now.addingTimeInterval(remaining)
            let start = now.addingTimeInterval(-state.elapsedSeconds)
            return (start, end)
        case .countUp:
            let start = now.addingTimeInterval(-state.elapsedSeconds)
            return (start, nil)
        }
    }

    /// When the system should treat content as stale and request a refresh from the app.
    static func staleDate(for state: FocusSessionState, now: Date = .now) -> Date? {
        guard !state.isPaused else { return nil }
        if state.mode.direction == .countDown, let remaining = state.remainingSeconds {
            return now.addingTimeInterval(remaining)
        }
        return nil
    }
}