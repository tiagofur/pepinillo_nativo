// FocusSessionRecord.swift
// Pepinillo — Deep Work Companion for Apple
//
// SwiftData model for persisted focus sessions.
// One record per completed (or abandoned) focus session.
// Named "Record" to avoid collision with the in-memory FocusSessionState.

import Foundation
import SwiftData

@Model
public final class FocusSessionRecord {
    @Attribute(.unique) public var id: UUID
    public var startedAt: Date
    public var endedAt: Date?

    // Mode & phase
    public var mode: String           // FocusMode.rawValue: "pomodoro", "flowtime", "timeBlock", "stopwatch"
    public var phase: String           // Last phase: "work", "shortBreak", "longBreak", "flow", "block", "freeform"

    // Duration
    public var targetDuration: TimeInterval?   // nil for Flowtime/Stopwatch
    public var actualDuration: TimeInterval    // actual elapsed focus time

    // Completion
    public var wasCompleted: Bool              // finished naturally vs abandoned
    public var interruptions: Int

    // Pause tracking
    public var pauseCount: Int = 0             // how many times the user paused
    public var totalPauseDuration: TimeInterval = 0  // total time spent paused

    // Pomodoro-specific
    public var pomodoroNumber: Int?            // e.g., 3 (of 4) — only for Pomodoro mode

    // Post-session journaling (C1)
    public var journalNote: String?
    public var satisfactionRating: Int?       // 1-5 scale (emoji-based)

    // Sync metadata
    public var isDirty: Bool = true
    public var syncedAt: Date?

    // Task relationship
    public var task: TaskItem?

    public init(from result: FocusSessionResult) {
        self.id = result.id
        self.startedAt = result.startedAt
        self.endedAt = result.endedAt
        self.mode = result.mode.rawValue
        self.phase = Self.phaseString(result.phase)
        self.targetDuration = result.targetDuration
        self.actualDuration = result.actualDuration
        self.wasCompleted = result.wasCompleted
        self.interruptions = result.interruptions
        self.pauseCount = result.pauseCount
        self.totalPauseDuration = result.totalPauseDuration
        self.pomodoroNumber = result.pomodoroNumber
    }

    /// Convenience initializer for creating from server sync data.
    public init(
        mode: String,
        phase: String,
        startedAt: Date,
        endedAt: Date?,
        actualDuration: TimeInterval,
        targetDuration: TimeInterval?,
        wasCompleted: Bool,
        interruptions: Int,
        pauseCount: Int,
        totalPauseDuration: TimeInterval
    ) {
        self.id = UUID()
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.mode = mode
        self.phase = phase
        self.targetDuration = targetDuration
        self.actualDuration = actualDuration
        self.wasCompleted = wasCompleted
        self.interruptions = interruptions
        self.pauseCount = pauseCount
        self.totalPauseDuration = totalPauseDuration
    }

    // MARK: - Helpers

    public var focusMode: FocusMode? {
        FocusMode(rawValue: mode)
    }

    public var durationFormatted: String {
        let minutes = Int(actualDuration) / 60
        let seconds = Int(actualDuration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private static func phaseString(_ phase: FocusPhase) -> String {
        switch phase {
        case .work:       return "work"
        case .shortBreak: return "shortBreak"
        case .longBreak:  return "longBreak"
        case .flow:       return "flow"
        case .flowBreak:  return "flowBreak"
        case .block:      return "block"
        case .freeform:   return "freeform"
        case .idle:       return "idle"
        case .paused:     return "paused"
        }
    }
}
