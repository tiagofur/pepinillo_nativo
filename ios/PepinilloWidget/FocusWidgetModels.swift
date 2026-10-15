// FocusWidgetModels.swift
// Pepinillo — Deep Work Companion for Apple
//
// Shared data types for the widget timeline provider and views.
// These are value types (Sendable/Codable) so they can cross process boundaries.

import Foundation
import WidgetKit

// MARK: - Widget Entry

struct FocusWidgetEntry: TimelineEntry {
    let date: Date
    let isProUser: Bool

    // Configuration
    let preferredModeID: String?
    let preferredTimerText: String
    /// Widget configuration toggles (S2). Views hide the streak row and mode
    /// breakdown unless these are on. Defaults match ConfigureFocusWidgetIntent
    /// and live on the explicit init below (a default here would pre-initialize
    /// the constant and forbid both passing and assigning it under Swift 6.4).
    let showStreak: Bool
    let showModeBreakdown: Bool

    // Session state (nil if no active session)
    let isSessionActive: Bool
    let isPaused: Bool
    /// True while the engine is in the "waiting for next phase" hold (tick suspended).
    /// Pause/Resume widget controls must be hidden/no-op during this state.
    let isWaiting: Bool
    let focusMode: String?        // FocusMode.rawValue
    let phase: String?
    let timerText: String?        // e.g. "23:14" or "34:02" for elapsed
    let progress: Double?         // 0.0–1.0 for countdown modes
    let pomodoroNumber: Int?
    let totalPomodoros: Int?
    let linkedTaskTitle: String?

    /// For countdown modes: the phase start date for Text(timerInterval:) live countdown.
    let timerStart: Date?
    /// For countdown modes: the target end date so widgets can use Text(timerInterval:) for a live timer.
    let timerEnd: Date?

    // Daily stats (always shown)
    let todayFocusMinutes: Int
    let todaySessionsCompleted: Int
    let currentStreakDays: Int
    /// True when a missed day was automatically bridged via Pro streak-protection.
    let streakProtectionApplied: Bool
    let dominantMode: String?     // FocusMode.rawValue

    // Mode breakdown for large widget
    let modeMinutes: [String: Int]  // ["pomodoro": 45, "flowtime": 30, ...]

    /// Explicit memberwise init (S2): Xcode 27's synthesized init does not
    /// accept the defaulted toggle arguments explicitly, so this pins the
    /// full parameter list with the same defaults.
    init(
        date: Date,
        isProUser: Bool,
        preferredModeID: String?,
        preferredTimerText: String,
        showStreak: Bool = true,
        showModeBreakdown: Bool = false,
        isSessionActive: Bool,
        isPaused: Bool,
        isWaiting: Bool,
        focusMode: String?,
        phase: String?,
        timerText: String?,
        progress: Double?,
        pomodoroNumber: Int?,
        totalPomodoros: Int?,
        linkedTaskTitle: String?,
        timerStart: Date?,
        timerEnd: Date?,
        todayFocusMinutes: Int,
        todaySessionsCompleted: Int,
        currentStreakDays: Int,
        streakProtectionApplied: Bool,
        dominantMode: String?,
        modeMinutes: [String: Int]
    ) {
        self.date = date
        self.isProUser = isProUser
        self.preferredModeID = preferredModeID
        self.preferredTimerText = preferredTimerText
        self.showStreak = showStreak
        self.showModeBreakdown = showModeBreakdown
        self.isSessionActive = isSessionActive
        self.isPaused = isPaused
        self.isWaiting = isWaiting
        self.focusMode = focusMode
        self.phase = phase
        self.timerText = timerText
        self.progress = progress
        self.pomodoroNumber = pomodoroNumber
        self.totalPomodoros = totalPomodoros
        self.linkedTaskTitle = linkedTaskTitle
        self.timerStart = timerStart
        self.timerEnd = timerEnd
        self.todayFocusMinutes = todayFocusMinutes
        self.todaySessionsCompleted = todaySessionsCompleted
        self.currentStreakDays = currentStreakDays
        self.streakProtectionApplied = streakProtectionApplied
        self.dominantMode = dominantMode
        self.modeMinutes = modeMinutes
    }

    static let placeholder = FocusWidgetEntry(
        date: Date(),
        isProUser: true,
        preferredModeID: "pomodoro",
        preferredTimerText: "25:00",
        isSessionActive: false,
        isPaused: false,
        isWaiting: false,
        focusMode: nil,
        phase: nil,
        timerText: nil,
        progress: nil,
        pomodoroNumber: nil,
        totalPomodoros: nil,
        linkedTaskTitle: nil,
        timerStart: nil,
        timerEnd: nil,
        todayFocusMinutes: 95,
        todaySessionsCompleted: 4,
        currentStreakDays: 7,
        streakProtectionApplied: false,
        dominantMode: "pomodoro",
        modeMinutes: ["pomodoro": 50, "flowtime": 30, "timeBlock": 15]
    )

    static let idle = FocusWidgetEntry(
        date: Date(),
        isProUser: false,
        preferredModeID: "pomodoro",
        preferredTimerText: "25:00",
        isSessionActive: false,
        isPaused: false,
        isWaiting: false,
        focusMode: nil,
        phase: nil,
        timerText: nil,
        progress: nil,
        pomodoroNumber: nil,
        totalPomodoros: nil,
        linkedTaskTitle: nil,
        timerStart: nil,
        timerEnd: nil,
        todayFocusMinutes: 0,
        todaySessionsCompleted: 0,
        currentStreakDays: 0,
        streakProtectionApplied: false,
        dominantMode: nil,
        modeMinutes: [:]
    )
}

// MARK: - Mode color helper (reusable in widget views)

struct WidgetModeStyle {
    let emoji: String
    let systemImage: String

    static func style(for mode: String) -> WidgetModeStyle {
        switch mode {
        case "pomodoro":  return WidgetModeStyle(emoji: "🍅", systemImage: "timer")
        case "flowtime":  return WidgetModeStyle(emoji: "🌊", systemImage: "wind")
        case "timeBlock": return WidgetModeStyle(emoji: "📦", systemImage: "rectangle.split.3x1")
        case "stopwatch": return WidgetModeStyle(emoji: "⏱️", systemImage: "stopwatch")
        default:          return WidgetModeStyle(emoji: "🧠", systemImage: "brain.head.profile")
        }
    }
}
