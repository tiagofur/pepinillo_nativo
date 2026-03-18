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

    // Session state (nil if no active session)
    let isSessionActive: Bool
    let isPaused: Bool
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
    let dominantMode: String?     // FocusMode.rawValue

    // Mode breakdown for large widget
    let modeMinutes: [String: Int]  // ["pomodoro": 45, "flowtime": 30, ...]

    static let placeholder = FocusWidgetEntry(
        date: Date(),
        isSessionActive: false,
        isPaused: false,
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
        dominantMode: "pomodoro",
        modeMinutes: ["pomodoro": 50, "flowtime": 30, "timeBlock": 15]
    )

    static let idle = FocusWidgetEntry(
        date: Date(),
        isSessionActive: false,
        isPaused: false,
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
