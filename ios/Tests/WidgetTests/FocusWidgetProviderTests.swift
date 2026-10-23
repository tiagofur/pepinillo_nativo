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

// MARK: - Staggered Timeline Tests

@Suite("FocusWidgetProvider — Staggered Entries")
struct FocusWidgetStaggeredEntriesTests {

    @Test("Mid-phase timeline anchors forward from now, never the past")
    func staggeredSnapshotsAnchorForwardFromNow() {
        // Regression: the first staggered implementation anchored from the
        // phase START, so every entry mid-phase dated in the past. WidgetKit
        // discarded them all — frozen ring, the exact live symptom.
        let now = Date.now
        let start = now.addingTimeInterval(-180) // phase started 3 min ago
        let end = now.addingTimeInterval(120)    // 2 min left

        let snapshots = staggeredTimelineSnapshots(start: start, now: now, end: end)

        #expect(snapshots.count >= 2)
        for snapshot in snapshots {
            #expect(snapshot.date >= now.addingTimeInterval(-1),
                    "Snapshot dated in the past collapses the timeline")
            #expect(snapshot.date <= end.addingTimeInterval(1))
        }
        for (prev, next) in zip(snapshots, snapshots.dropFirst()) {
            #expect(next.date > prev.date)
        }
    }

    @Test("Staggered progress climbs toward 1 at phase end")
    func staggeredProgressClimbsToOne() {
        let now = Date.now
        let start = now.addingTimeInterval(-180)
        let end = now.addingTimeInterval(120)

        let snapshots = staggeredTimelineSnapshots(start: start, now: now, end: end)

        #expect(snapshots.count >= 2)
        for (prev, next) in zip(snapshots, snapshots.dropFirst()) {
            #expect(next.progress >= prev.progress)
        }
        #expect(abs((snapshots.last?.progress ?? 0) - 1.0) < 0.01)
        // Mid-phase progress must reflect elapsed wall time (~180/300 = 0.6).
        #expect(abs((snapshots.first?.progress ?? 0) - 0.6) < 0.05)
    }

    @Test("Staggering caps snapshot count on long phases")
    func staggeredSnapshotsCapCount() {
        let now = Date.now

        let snapshots = staggeredTimelineSnapshots(
            start: now, now: now, end: now.addingTimeInterval(7200))

        #expect(snapshots.count <= 100)
        #expect(snapshots.count >= 2)
    }

    @Test("Short phases get dense near-live snapshots")
    func staggeredSnapshotsDenseOnShortPhases() {
        // A 2-minute test phase should spread ~90 snapshots (~1.3 s apart,
        // floored at 2 s) so the ring feels near-live — not the old 30 s gait.
        let now = Date.now
        let end = now.addingTimeInterval(120)

        let snapshots = staggeredTimelineSnapshots(
            start: now.addingTimeInterval(-180), now: now, end: end)

        #expect(snapshots.count >= 50)
        let gaps = zip(snapshots, snapshots.dropFirst()).map {
            $1.date.timeIntervalSince($0.date)
        }
        #expect(gaps.allSatisfy { $0 >= 1.9 && $0 <= 3.5 })
        for (prev, next) in zip(snapshots, snapshots.dropFirst()) {
            #expect(next.progress >= prev.progress)
        }
    }

    @Test("Ended phase yields no snapshots")
    func staggeredSnapshotsEmptyWhenEnded() {
        let now = Date.now

        let snapshots = staggeredTimelineSnapshots(
            start: now.addingTimeInterval(-300),
            now: now,
            end: now.addingTimeInterval(-1))

        #expect(snapshots.isEmpty)
    }
}
