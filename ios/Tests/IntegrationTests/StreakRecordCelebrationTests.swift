// StreakRecordCelebrationTests.swift
// Pepinillo — Deep Work Companion for Apple
//
// Eligibility rule for the streak-record celebration (#734) — mirrors the
// Android StreakRecordCelebrationTest suite (PR #731) for cross-platform parity.

import Testing
import Foundation
@testable import Pepinillo

struct StreakRecordCelebrationTests {

    @Test func recordAtTwoDaysWithSingleDayHistoryFires() {
        // yesterday-only history: previousBest = 1; today's session lifts streak to 2
        #expect(StreakRecordCelebration.isEligible(currentStreak: 2, previousBest: 1))
    }

    @Test func firstEverStreakDoesNotCelebrate() {
        // day 1: streak 1 > best 0, but trivial records are not celebrated
        #expect(!StreakRecordCelebration.isEligible(currentStreak: 1, previousBest: 0))
    }

    @Test func tieWithBestDoesNotCelebrate() {
        #expect(!StreakRecordCelebration.isEligible(currentStreak: 5, previousBest: 5))
    }

    @Test func streakBelowBestDoesNotCelebrate() {
        #expect(!StreakRecordCelebration.isEligible(currentStreak: 3, previousBest: 7))
    }

    @Test func previouslyCelebratedValueDoesNotFireAgain() {
        #expect(!StreakRecordCelebration.isEligible(
            currentStreak: 4,
            previousBest: 3,
            lastCelebrated: 4
        ))
    }

    @Test func streakBeyondLastCelebratedFiresEvenIfBestIsStale() {
        #expect(StreakRecordCelebration.isEligible(
            currentStreak: 8,
            previousBest: 2,
            lastCelebrated: 3
        ))
    }

    @Test func disabledToggleSuppressesEverything() {
        #expect(!StreakRecordCelebration.isEligible(
            currentStreak: 10,
            previousBest: 2,
            enabled: false
        ))
    }

    @Test func previousBestIncludingTodayNeverFires() {
        // The caller MUST exclude today's row from previousBest history — this
        // documents the guard the AppFeature effect relies on.
        #expect(!StreakRecordCelebration.isEligible(currentStreak: 6, previousBest: 6))
    }

    @Test func previousBestExcludingTodayIgnoresTodayRows() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: today)!
        let history = [
            DailyStatsDTO(date: yesterday, totalFocusMinutes: 25, sessionsCompleted: 1, tasksCompleted: 0),
            DailyStatsDTO(date: today, totalFocusMinutes: 5, sessionsCompleted: 1, tasksCompleted: 0),
        ]
        // Today excluded → only yesterday counts → best 1 (not 2).
        #expect(StreakRecordCelebration.previousBestExcludingToday(
            from: history,
            todayStart: today,
            calendar: calendar
        ) == 1)

        // Two consecutive past days → best 2.
        let twoDayRun = [
            DailyStatsDTO(date: twoDaysAgo, totalFocusMinutes: 25, sessionsCompleted: 1, tasksCompleted: 0),
            DailyStatsDTO(date: yesterday, totalFocusMinutes: 25, sessionsCompleted: 1, tasksCompleted: 0),
        ]
        #expect(StreakRecordCelebration.previousBestExcludingToday(
            from: twoDayRun,
            todayStart: today,
            calendar: calendar
        ) == 2)
    }

    @Test func previousBestIgnoresRowsWithoutCompletedSessions() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: today)!
        let history = [
            DailyStatsDTO(date: twoDaysAgo, totalFocusMinutes: 25, sessionsCompleted: 1, tasksCompleted: 0),
            DailyStatsDTO(date: yesterday, totalFocusMinutes: 0, sessionsCompleted: 0, tasksCompleted: 0),
        ]
        // The empty yesterday breaks the run → best stays 1.
        #expect(StreakRecordCelebration.previousBestExcludingToday(
            from: history,
            todayStart: today,
            calendar: calendar
        ) == 1)
    }
}
