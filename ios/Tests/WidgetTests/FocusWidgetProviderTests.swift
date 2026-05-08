// FocusWidgetProviderTests.swift
// Pepinillo — Deep Work Companion for Apple
//
// Tests for widget-related logic: DailyStats aggregation, streak computation, AppGroup URL.
// Avoids SwiftData ModelContainer to prevent conflicts with the test host app's container.

import Testing
import Foundation
@testable import Pepinillo

@Suite("FocusWidgetProvider")
struct FocusWidgetProviderTests {

    // MARK: - Streak Calculation Tests

    @Test("Empty stats array returns zero streak")
    func testEmptyStreak() {
        let streak = computeStreak(from: [], today: Calendar.current.startOfDay(for: Date()))
        #expect(streak == 0)
    }

    @Test("One consecutive day gives streak of 1")
    func testOneDayStreak() {
        let today = Calendar.current.startOfDay(for: Date())
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!

        let stats = DailyStats(date: yesterday)
        stats.hadFocusSession = true

        let streak = computeStreak(from: [stats], today: today)
        #expect(streak == 1)
    }

    @Test("Three consecutive days gives streak of 3")
    func testThreeDayStreak() {
        let today = Calendar.current.startOfDay(for: Date())
        var allStats: [DailyStats] = []
        for offset in 1...3 {
            let day = Calendar.current.date(byAdding: .day, value: -offset, to: today)!
            let stats = DailyStats(date: day)
            stats.hadFocusSession = true
            allStats.append(stats)
        }

        let streak = computeStreak(from: allStats, today: today)
        #expect(streak == 3)
    }

    @Test("Gap in streak resets count")
    func testStreakWithGap() {
        let today = Calendar.current.startOfDay(for: Date())
        // Day -1: had session
        // Day -2: NO session (gap)
        // Day -3: had session
        var allStats: [DailyStats] = []
        for offset in [1, 3] {
            let day = Calendar.current.date(byAdding: .day, value: -offset, to: today)!
            let stats = DailyStats(date: day)
            stats.hadFocusSession = true
            allStats.append(stats)
        }

        let streak = computeStreak(from: allStats, today: today)
        #expect(streak == 1)  // Only the most recent consecutive day counts
    }

    // MARK: - Daily Stats Aggregation

    @Test("DailyStats recordSession accumulates minutes correctly")
    func testRecordSessionAccumulates() {
        let stats = DailyStats(date: Date())

        let now = Date()
        let result1 = FocusSessionResult(
            id: UUID(), mode: .pomodoro, phase: .work(number: 1, total: 4),
            startedAt: now, endedAt: now.addingTimeInterval(1500),
            targetDuration: 1500, actualDuration: 1500,
            wasCompleted: true, interruptions: 0,
            pomodoroNumber: 1, linkedTaskID: nil
        )
        let result2 = FocusSessionResult(
            id: UUID(), mode: .flowtime, phase: .flow,
            startedAt: now, endedAt: now.addingTimeInterval(2700),
            targetDuration: nil, actualDuration: 2700,
            wasCompleted: true, interruptions: 0,
            pomodoroNumber: nil, linkedTaskID: nil
        )

        stats.recordSession(result1)
        stats.recordSession(result2)

        #expect(stats.totalFocusMinutes == 70)   // (1500 + 2700) / 60
        #expect(stats.sessionsCompleted == 2)
        #expect(stats.pomodoroSeconds == 1500)
        #expect(stats.flowtimeSeconds == 2700)
        #expect(stats.hadFocusSession == true)
        #expect(stats.dominantMode == .flowtime)
    }

    // MARK: - AppGroup URL

    @Test("AppGroup.storeURL is a valid file URL")
    func testAppGroupURL() {
        let url = AppGroup.storeURL
        #expect(url.isFileURL)
        #expect(url.lastPathComponent == AppGroup.storeFileName)
        #expect(url.lastPathComponent == "PepinilloLocal.sqlite")
        #expect(url.lastPathComponent != AppGroup.legacyCloudKitStoreFileName)
    }
}

// MARK: - Array-Based Streak Helper (mirrors widget logic without SwiftData)

private func computeStreak(from allStats: [DailyStats], today: Date) -> Int {
    var streak = 0
    var checkDate = today

    for _ in 0..<365 {
        let previousDay = Calendar.current.date(byAdding: .day, value: -1, to: checkDate)!

        // Find stats for the previous day
        let found = allStats.first { stats in
            stats.hadFocusSession &&
            stats.date >= previousDay &&
            stats.date < checkDate
        }

        guard found != nil else { break }
        streak += 1
        checkDate = previousDay
    }
    return streak
}
