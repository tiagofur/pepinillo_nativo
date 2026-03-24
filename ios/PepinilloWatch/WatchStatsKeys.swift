// WatchStatsKeys.swift
// Pepinillo — Deep Work Companion for Apple
//
// UserDefaults keys shared between Watch features and complications.
// Extracted to a standalone file so iOS targets can compile Watch feature
// reducers for testing without pulling in ClockKit dependencies.

import Foundation

// MARK: - Shared UserDefaults Keys (Watch-side)

enum WatchStatsKeys {
    static let todayFocusMinutes = "watch.todayFocusMinutes"
    static let currentStreakDays = "watch.currentStreakDays"
    static let todaySessionsCompleted = "watch.todaySessionsCompleted"
    static let isSessionActive = "watch.isSessionActive"
    static let displayTime = "watch.displayTime"
    static let modeEmoji = "watch.modeEmoji"
    static let linkedTaskTitle = "watch.linkedTaskTitle"
    static let phaseName = "watch.phaseName"
    static let progress = "watch.progress"
    static let pomodoroNumber = "watch.pomodoroNumber"
    static let phaseStartDate = "watch.phaseStartDate"
    static let phaseEndDate = "watch.phaseEndDate"

    // Task complication keys
    static let tasksJSON = "watch.tasksJSON"
    static let tasksCompletedCount = "watch.tasksCompletedCount"
    static let tasksTotalCount = "watch.tasksTotalCount"
}
