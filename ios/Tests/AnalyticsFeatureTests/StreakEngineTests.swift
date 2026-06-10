// StreakEngineTests.swift
// Pepinillo — Deep Work Companion for Apple
//
// Unit tests for the pure StreakEngine.computeStreak function.
// No SwiftData, no MainActor, no network.

import Testing
import Foundation
@testable import Pepinillo

@Suite("StreakEngine")
struct StreakEngineTests {

    // MARK: - Helpers

    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }

    /// Returns a date at UTC midnight offset by `daysAgo` days before `today`.
    private func day(_ daysAgo: Int, from today: Date, cal: Calendar) -> Date {
        cal.date(byAdding: .day, value: -daysAgo, to: cal.startOfDay(for: today))!
    }

    // MARK: - Free user (no protection)

    @Test("Free user with no active days returns 0 streak")
    func freeUser_emptyHistory_returnsZero() {
        let cal = calendar
        let today = cal.startOfDay(for: Date.now)
        let result = StreakEngine.computeStreak(activeDays: [], isProUser: false, today: today, calendar: cal)
        #expect(result.streak == 0)
        #expect(result.protectionApplied == false)
    }

    @Test("Free user with 5 consecutive days returns 5")
    func freeUser_fiveConsecutiveDays_returnsFive() {
        let cal = calendar
        let today = cal.startOfDay(for: Date.now)
        // Days: yesterday, 2 days ago, 3, 4, 5
        let activeDays = (1...5).map { day($0, from: today, cal: cal) }
        let result = StreakEngine.computeStreak(activeDays: activeDays, isProUser: false, today: today, calendar: cal)
        #expect(result.streak == 5)
        #expect(result.protectionApplied == false)
    }

    @Test("Free user with one miss breaks the streak immediately")
    func freeUser_oneMissBetweenActiveDays_breaksAtMiss() {
        let cal = calendar
        let today = cal.startOfDay(for: Date.now)
        // Active: yesterday (1), 3 days ago (3) — day 2 is a miss
        let activeDays = [day(1, from: today, cal: cal), day(3, from: today, cal: cal)]
        let result = StreakEngine.computeStreak(activeDays: activeDays, isProUser: false, today: today, calendar: cal)
        #expect(result.streak == 1)
        #expect(result.protectionApplied == false)
    }

    @Test("Free user with no activity yesterday returns 0 even if older days are active")
    func freeUser_noActivityYesterday_returnsZero() {
        let cal = calendar
        let today = cal.startOfDay(for: Date.now)
        // Active: 2 days ago and older only
        let activeDays = (2...7).map { day($0, from: today, cal: cal) }
        let result = StreakEngine.computeStreak(activeDays: activeDays, isProUser: false, today: today, calendar: cal)
        #expect(result.streak == 0)
        #expect(result.protectionApplied == false)
    }

    // MARK: - Pro user: skip applied

    @Test("Pro user with one miss between active days gets streak protected")
    func proUser_oneMiss_streakProtected() {
        let cal = calendar
        let today = cal.startOfDay(for: Date.now)
        // Active: 1, 3, 4, 5 days ago; day 2 is a miss
        let activeDays = [
            day(1, from: today, cal: cal),
            day(3, from: today, cal: cal),
            day(4, from: today, cal: cal),
            day(5, from: today, cal: cal),
        ]
        let result = StreakEngine.computeStreak(activeDays: activeDays, isProUser: true, today: today, calendar: cal)
        #expect(result.streak == 5)  // 1(active) + 2(skipped) + 3+4+5(active) = 5
        #expect(result.protectionApplied == true)
    }

    @Test("Pro user with two consecutive misses — streak breaks at second miss")
    func proUser_twoConsecutiveMisses_breaksAtSecondMiss() {
        let cal = calendar
        let today = cal.startOfDay(for: Date.now)
        // Active: 1, 4 days ago; days 2 and 3 are misses
        let activeDays = [
            day(1, from: today, cal: cal),
            day(4, from: today, cal: cal),
        ]
        let result = StreakEngine.computeStreak(activeDays: activeDays, isProUser: true, today: today, calendar: cal)
        // Day 2 is a miss — day 3 (the one before day 2) is also a miss → no skip applies
        #expect(result.streak == 1)
        #expect(result.protectionApplied == false)
    }

    @Test("Pro user: two misses within 7-day window — only first miss is bridged")
    func proUser_twoMissesWithin7Days_onlyFirstBridged() {
        let cal = calendar
        let today = cal.startOfDay(for: Date.now)
        // Active: 1, 3, 5, 7 days ago; misses at 2 and 4
        // Skip at day 2 → advances to day 3 (active)
        // Miss at day 4 is within 7 days of the day 2 skip → no second skip allowed
        let activeDays = [
            day(1, from: today, cal: cal),
            day(3, from: today, cal: cal),
            day(5, from: today, cal: cal),
            day(7, from: today, cal: cal),
        ]
        let result = StreakEngine.computeStreak(activeDays: activeDays, isProUser: true, today: today, calendar: cal)
        // Streak: 1(active) + 2(skip) + 3(active) = 3, then 4 miss within 7-day window → break
        #expect(result.streak == 3)
        #expect(result.protectionApplied == true)
    }

    @Test("Pro user: two misses exactly 7 days apart — both bridged")
    func proUser_twoMissesExactly7DaysApart_bothBridged() {
        let cal = calendar
        let today = cal.startOfDay(for: Date.now)
        // Active: 1,3,4,5,6,7,9,10 — misses at 2 and 8
        // Skip at day 2 (window: day 2); skip at day 8 = 6 days after day 2 → within 7 days → NOT bridged
        // Re-test: misses at 2 and 10, active 1,3,...,9,11
        // days 2 (miss) and 10 (miss) are 8 days apart
        let activeDays = (3...9).map { day($0, from: today, cal: cal) } + [
            day(1, from: today, cal: cal),
            day(11, from: today, cal: cal),
            day(12, from: today, cal: cal),
        ]
        let result = StreakEngine.computeStreak(activeDays: activeDays, isProUser: true, today: today, calendar: cal)
        // Streak: 1 + skip(2) + 3+4+5+6+7+8+9 + skip(10) + 11+12 = 13 — wait, 8 is active, so let's recount:
        // Actually days 3-9 are all active (7 days), so:
        // 1(active) + 2(skip) + 3..9(7 active) + 10(miss, 8 days after skip at 2) + 11+12
        // Day 10 miss: lastSkipUsedOn=day2, daysSinceLastSkip from day2 to day10 = 8 ≥ 7 → OK
        // Streak = 1 + 1(skip) + 7 + 1(skip) + 2 = 12
        #expect(result.streak == 12)
        #expect(result.protectionApplied == true)
    }

    @Test("Pro user: miss at the very start (yesterday) with active days before — no skip since no prior active chain")
    func proUser_missIsYesterdayWithNoPriorChain_returnsZero() {
        let cal = calendar
        let today = cal.startOfDay(for: Date.now)
        // Only day 2+ are active; yesterday (day 1) is a miss
        // Skip requires the day before the miss (day 2) to be active — it IS, but the algo
        // walks backwards: checkDate=today → prevDay=day1 → miss → check day2 (active?) YES
        // → apply skip → streak = 1 (the skipped day), then advance to day2 (already counted)
        // Actually after the skip the loop sets checkDate = dayBeforeMiss (= day 2),
        // but day 2 is active so on NEXT iteration prevDay = day 3, etc.
        let activeDays = (2...6).map { day($0, from: today, cal: cal) }
        let result = StreakEngine.computeStreak(activeDays: activeDays, isProUser: true, today: today, calendar: cal)
        // day 1 miss + day 2 is active → skip applies:
        // streak = 1 (skip) + 2+3+4+5+6 = 6
        #expect(result.streak == 6)
        #expect(result.protectionApplied == true)
    }

    @Test("Pro user: yesterday is active but miss at day 2 — protected")
    func proUser_yesterdayActiveWithMissAtDay2_protected() {
        let cal = calendar
        let today = cal.startOfDay(for: Date.now)
        // day1 active, day2 miss, day3+ active
        let activeDays = [day(1, from: today, cal: cal)] + (3...8).map { day($0, from: today, cal: cal) }
        let result = StreakEngine.computeStreak(activeDays: activeDays, isProUser: true, today: today, calendar: cal)
        #expect(result.streak == 8)
        #expect(result.protectionApplied == true)
    }

    @Test("Pro user empty history returns zero")
    func proUser_emptyHistory_returnsZero() {
        let cal = calendar
        let today = cal.startOfDay(for: Date.now)
        let result = StreakEngine.computeStreak(activeDays: [], isProUser: true, today: today, calendar: cal)
        #expect(result.streak == 0)
        #expect(result.protectionApplied == false)
    }

    @Test("Pro user: only today is active (no yesterday) returns 0")
    func proUser_onlyTodayIsActive_returnsZero() {
        let cal = calendar
        let today = cal.startOfDay(for: Date.now)
        // Today itself is not included in the backwards walk (we look at yesterday first)
        let activeDays = [today]
        let result = StreakEngine.computeStreak(activeDays: activeDays, isProUser: true, today: today, calendar: cal)
        #expect(result.streak == 0)
        #expect(result.protectionApplied == false)
    }

    @Test("Free user: only today is active returns 0")
    func freeUser_onlyTodayIsActive_returnsZero() {
        let cal = calendar
        let today = cal.startOfDay(for: Date.now)
        let activeDays = [today]
        let result = StreakEngine.computeStreak(activeDays: activeDays, isProUser: false, today: today, calendar: cal)
        #expect(result.streak == 0)
        #expect(result.protectionApplied == false)
    }

    @Test("Pro user: miss exactly 7 days after last skip is bridged")
    func proUser_missExactly7DaysAfterLastSkip_bridged() {
        let cal = calendar
        let today = cal.startOfDay(for: Date.now)
        // Active days: 1,3,4,5,6,7,8,10 — miss at 2 and 9
        // Skip at day 2: daysSince = 0, lastSkipUsedOn = day 2
        // Miss at day 9: daysSinceLastSkip from day2 to day9 = 7 ≥ 7 → OK to skip
        let activeDays = [
            day(1, from: today, cal: cal),
            day(3, from: today, cal: cal),
            day(4, from: today, cal: cal),
            day(5, from: today, cal: cal),
            day(6, from: today, cal: cal),
            day(7, from: today, cal: cal),
            day(8, from: today, cal: cal),
            day(10, from: today, cal: cal),
        ]
        let result = StreakEngine.computeStreak(activeDays: activeDays, isProUser: true, today: today, calendar: cal)
        // streak = 1 + skip(2) + 3+4+5+6+7+8 + skip(9) + 10 = 10
        #expect(result.streak == 10)
        #expect(result.protectionApplied == true)
    }
}
