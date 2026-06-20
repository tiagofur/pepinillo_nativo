// StreakProtectionTests.swift
// Pepinillo — Deep Work Companion for Apple
//
// Unit tests for StreakProtectionService.
// Tests the pure function: history + isPro + today → StreakResult.

import Testing
import Foundation
@testable import Pepinillo

@Suite("StreakProtectionService")
struct StreakProtectionTests {

    // MARK: - Test helpers

    private let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }()

    /// Build a DailyStatsDTO for a given day offset from a reference date.
    private func stat(daysAgo offset: Int, from reference: Date, sessionsCompleted: Int = 1) -> DailyStatsDTO {
        let date = calendar.date(byAdding: .day, value: -offset, to: reference)!
        return DailyStatsDTO(
            date: date,
            totalFocusMinutes: sessionsCompleted * 25,
            sessionsCompleted: sessionsCompleted,
            tasksCompleted: 0
        )
    }

    /// A fixed "today" for deterministic tests (noon UTC on an arbitrary date).
    private var today: Date {
        var comps = DateComponents()
        comps.year = 2025; comps.month = 6; comps.day = 15
        comps.hour = 12; comps.minute = 0; comps.second = 0
        return calendar.date(from: comps)!
    }

    private func compute(history: [DailyStatsDTO], isPro: Bool) -> StreakResult {
        StreakProtectionService.computeProtectedStreak(
            history: history,
            isPro: isPro,
            today: today,
            calendar: calendar
        )
    }

    // MARK: - Basic cases

    @Test("Empty history returns zero streak")
    func emptyHistory() {
        let result = compute(history: [], isPro: false)
        #expect(result == .zero)
    }

    @Test("Empty history Pro returns zero streak")
    func emptyHistoryPro() {
        let result = compute(history: [], isPro: true)
        #expect(result == .zero)
    }

    @Test("No missed days — full consecutive streak")
    func noMissedDays() {
        // Today + 4 prior days = 5-day streak
        let history = (0..<5).map { stat(daysAgo: $0, from: today) }
        let result = compute(history: history, isPro: false)
        #expect(result.days == 5)
        #expect(result.protectionApplied == false)
    }

    @Test("No missed days Pro — same as free")
    func noMissedDaysPro() {
        let history = (0..<5).map { stat(daysAgo: $0, from: today) }
        let result = compute(history: history, isPro: true)
        #expect(result.days == 5)
        #expect(result.protectionApplied == false)
    }

    // MARK: - Free user breaks on miss

    @Test("Free user: one missed day breaks streak")
    func freeUserBreaksOnMiss() {
        // Days 0 (today), 1, skip 2, 3, 4
        let history = [0, 1, 3, 4].map { stat(daysAgo: $0, from: today) }
        let result = compute(history: history, isPro: false)
        #expect(result.days == 2)  // today + yesterday
        #expect(result.protectionApplied == false)
    }

    // MARK: - Pro protection: one miss covered

    @Test("Pro user: one missed day is auto-covered")
    func proOneMissCovered() {
        // Today, skip 1, days 2-5 → should yield 6 days with protection
        let history = [0, 2, 3, 4, 5].map { stat(daysAgo: $0, from: today) }
        let result = compute(history: history, isPro: true)
        #expect(result.days == 6)
        #expect(result.protectionApplied == true)
    }

    // MARK: - Two misses within 7 days breaks streak on the second

    @Test("Pro user: two misses within 7 days — second breaks streak")
    func proTwoMissesInSevenDays() {
        // Today (0), skip 1, days 2-3, skip 4 (second miss within 7 days), day 5
        // First skip at 1 → second skip at 4 (only 3 days apart) → must break at 4
        let history = [0, 2, 3, 5].map { stat(daysAgo: $0, from: today) }
        let result = compute(history: history, isPro: true)
        // Walk: day 0 ✓(1), day 1 skip(2, protection), day 2 ✓(3), day 3 ✓(4),
        //        day 4 miss again — last skip at day 1, daysApart=3 < 7 → break
        #expect(result.days == 4)
        #expect(result.protectionApplied == true)
    }

    // MARK: - Boundary: exactly 7 days between skips

    @Test("Pro user: second skip exactly 7 days after first is allowed")
    func proSecondSkipExactlySevenDaysLater() {
        // Skip at day 1, then skip again at day 8 (7 days apart).
        // Active days: 0, 2-7, 9-10
        var daysActive = Array(0..<1)    // today
        daysActive += Array(2...7)       // days 2-7
        daysActive += Array(9...10)      // days 9-10
        let history = daysActive.map { stat(daysAgo: $0, from: today) }
        let result = compute(history: history, isPro: true)
        // Skips at day 1 and day 8 (8-1 = 7 days apart → allowed)
        // Expected: 0+skip+2+3+4+5+6+7+skip+9+10 = 11 days
        #expect(result.days == 11)
        #expect(result.protectionApplied == true)
    }

    @Test("Pro user: second skip only 6 days after first — breaks")
    func proSecondSkipSixDaysBreaks() {
        // Skip at day 1, miss again at day 7 (only 6 days apart).
        // Active days: 0, 2-6, 8-9
        var daysActive = [0]
        daysActive += Array(2...6)
        daysActive += [8, 9]
        let history = daysActive.map { stat(daysAgo: $0, from: today) }
        let result = compute(history: history, isPro: true)
        // After skipping day 1, streak covers today(0), skip(1), 2,3,4,5,6 → then day 7 miss
        // last skip was at 1, days apart = 6 < 7 → break at day 7
        #expect(result.days == 7)
        #expect(result.protectionApplied == true)
    }

    // MARK: - Miss on first day (yesterday missed with today active)

    @Test("Pro: miss on day 1 (yesterday), today active")
    func proMissYesterday() {
        // Only today + days 2-4, yesterday (1) missed
        let history = [0, 2, 3, 4].map { stat(daysAgo: $0, from: today) }
        let result = compute(history: history, isPro: true)
        #expect(result.days == 5)
        #expect(result.protectionApplied == true)
    }

    // MARK: - Today in-progress (no session yet today)

    @Test("Free: no session today is neutral — streak anchors at yesterday")
    func freeNoSessionTodayIsNeutral() {
        // No entry for today; yesterday and 2 days ago have sessions.
        // Today is in-progress and should not break the streak.
        let history = [1, 2, 3].map { stat(daysAgo: $0, from: today) }
        let result = compute(history: history, isPro: false)
        #expect(result.days == 3)  // streak runs from yesterday back 3 days
        #expect(result.protectionApplied == false)
    }

    @Test("Pro: no session today is neutral — streak anchors at yesterday, skip NOT consumed by today")
    func proNoSessionTodayNeutral() {
        // No entry for today; previous 4 days active.
        // Today is neutral — the skip must NOT be consumed on today.
        let history = [1, 2, 3, 4].map { stat(daysAgo: $0, from: today) }
        let result = compute(history: history, isPro: true)
        // Walk starts at yesterday (day 1), all 4 days active → 4-day streak, no skip used.
        #expect(result.days == 4)
        #expect(result.protectionApplied == false)
    }

    @Test("Pro: no session today + covered miss 3 days ago — skip consumed by miss only")
    func proNoSessionTodayWithCoveredMissEarlier() {
        // Today: no session (neutral). Days 1, 2, 4, 5 active; day 3 is a miss.
        // Expected: walk starts at yesterday (1), covers 1,2, skip day 3, continues 4,5 → 5 days.
        // Skip is consumed by day-3 miss, not by today.
        let history = [1, 2, 4, 5].map { stat(daysAgo: $0, from: today) }
        let result = compute(history: history, isPro: true)
        #expect(result.days == 5)
        #expect(result.protectionApplied == true)
    }

    // MARK: - Only today active

    @Test("Single day (today) returns 1 for both free and Pro")
    func singleDayToday() {
        let history = [stat(daysAgo: 0, from: today)]
        #expect(compute(history: history, isPro: false).days == 1)
        #expect(compute(history: history, isPro: true).days == 1)
    }

    // MARK: - Sessions = 0 treated as no session

    @Test("Entry with sessionsCompleted = 0 counts as missed day")
    func zeroSessionsCountsAsMissed() {
        let missedDay = DailyStatsDTO(
            date: calendar.date(byAdding: .day, value: -1, to: today)!,
            totalFocusMinutes: 0,
            sessionsCompleted: 0,
            tasksCompleted: 0
        )
        let history = [stat(daysAgo: 0, from: today), missedDay]
        let freeResult = compute(history: history, isPro: false)
        #expect(freeResult.days == 1)  // only today; yesterday has 0 sessions
    }

    @Test("Pro user with zero focus history (only missed days) has zero streak and no protection applied")
    func proZeroFocusHistory() {
        let missedDay = DailyStatsDTO(
            date: calendar.date(byAdding: .day, value: -1, to: today)!,
            totalFocusMinutes: 0,
            sessionsCompleted: 0,
            tasksCompleted: 0
        )
        let result = compute(history: [missedDay], isPro: true)
        #expect(result.days == 0)
        #expect(result.protectionApplied == false)
    }
}
