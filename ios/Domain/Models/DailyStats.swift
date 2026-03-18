// DailyStats.swift
// Pepinillo — Deep Work Companion for Apple
//
// Aggregated daily statistics. One record per day.
// Includes per-mode breakdown for the analytics dashboard.
// Syncs via CloudKit for cross-device analytics.

import Foundation
import SwiftData

@Model
public final class DailyStats {
    public var id: UUID
    public var date: Date                   // Normalized to start of day (midnight)

    // Totals
    public var totalFocusSeconds: Int
    public var sessionsCompleted: Int
    public var tasksCompleted: Int
    public var longestStreak: Int           // Consecutive completed sessions without interruption

    // Per-mode breakdown (Deep Work pivot: this is what makes our analytics unique)
    public var pomodoroSeconds: Int
    public var flowtimeSeconds: Int
    public var timeBlockSeconds: Int
    public var stopwatchSeconds: Int
    public var pomodoroCount: Int
    public var flowtimeCount: Int
    public var timeBlockCount: Int
    public var stopwatchCount: Int

    // Streak tracking
    public var hadFocusSession: Bool        // Did the user focus at all today?

    public init(date: Date) {
        self.id = UUID()
        self.date = Calendar.current.startOfDay(for: date)
        self.totalFocusSeconds = 0
        self.sessionsCompleted = 0
        self.tasksCompleted = 0
        self.longestStreak = 0
        self.pomodoroSeconds = 0
        self.flowtimeSeconds = 0
        self.timeBlockSeconds = 0
        self.stopwatchSeconds = 0
        self.pomodoroCount = 0
        self.flowtimeCount = 0
        self.timeBlockCount = 0
        self.stopwatchCount = 0
        self.hadFocusSession = false
    }

    // MARK: - Update Methods

    public func recordSession(_ result: FocusSessionResult) {
        let seconds = Int(result.actualDuration)
        totalFocusSeconds += seconds
        sessionsCompleted += 1
        hadFocusSession = true

        // Per-mode breakdown
        switch result.mode {
        case .pomodoro:
            pomodoroSeconds += seconds
            pomodoroCount += 1
        case .flowtime:
            flowtimeSeconds += seconds
            flowtimeCount += 1
        case .timeBlock:
            timeBlockSeconds += seconds
            timeBlockCount += 1
        case .stopwatch:
            stopwatchSeconds += seconds
            stopwatchCount += 1
        }
    }

    // MARK: - Computed

    public var totalFocusMinutes: Int { totalFocusSeconds / 60 }
    public var totalFocusHours: Double { Double(totalFocusSeconds) / 3600.0 }

    /// Returns the dominant mode for this day (most seconds).
    public var dominantMode: FocusMode? {
        let modes: [(FocusMode, Int)] = [
            (.pomodoro, pomodoroSeconds),
            (.flowtime, flowtimeSeconds),
            (.timeBlock, timeBlockSeconds),
            (.stopwatch, stopwatchSeconds)
        ]
        return modes.max(by: { $0.1 < $1.1 })?.0
    }

    /// Mode distribution as percentages.
    public var modeDistribution: [FocusMode: Double] {
        guard totalFocusSeconds > 0 else { return [:] }
        let total = Double(totalFocusSeconds)
        return [
            .pomodoro: Double(pomodoroSeconds) / total,
            .flowtime: Double(flowtimeSeconds) / total,
            .timeBlock: Double(timeBlockSeconds) / total,
            .stopwatch: Double(stopwatchSeconds) / total
        ]
    }
}
