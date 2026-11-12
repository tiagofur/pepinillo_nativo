// StreakRecordCelebration.swift
// Pepinillo — Deep Work Companion for Apple
//
// Pure, stateless rule for when a completed focus session deserves a "new streak
// record" celebration (#734). Mirrors the Android implementation (PR #731) —
// StreakRecordCelebration.kt — so both platforms fire identically.
//
// Eligibility (all must hold):
//   - enabled — user toggle (celebrateStreakRecords, device-local).
//   - currentStreak ≥ minCelebratedStreak — a first-ever streak (1 day) makes
//     everything a record; celebrating it dilutes the moment. Day 2 is the
//     critical retention peak and is the first celebration.
//   - currentStreak > previousBest — strictly beats the best streak, where
//     previousBest EXCLUDES today's row (including today would make
//     previousBest ≥ currentStreak always and nothing would ever fire).
//   - currentStreak > lastCelebrated — anti-repeat latch (survives process
//     death); the daily granularity of streaks already prevents double-firing
//     within one day.
//
// Coexistence rule: when the day is ALSO a fixed milestone ([3, 7, 14, 30, 60,
// 100] — CelebrationMilestone), the milestone's full-screen overlay wins and
// the record only consumes the latch (one celebration overlay at a time).

import Foundation

/// A confirmed new record, ready for presentation.
struct StreakRecord: Equatable {
    /// The streak value that just became the all-time best.
    let newBest: Int
    /// The previous all-time best (today excluded) — kept for analytics/copy.
    let previousBest: Int
}

enum StreakRecordCelebration {

    /// Minimum streak length worth celebrating.
    static let minCelebratedStreak = 2

    static func isEligible(
        currentStreak: Int,
        previousBest: Int,
        lastCelebrated: Int = 0,
        enabled: Bool = true
    ) -> Bool {
        enabled
            && currentStreak >= minCelebratedStreak
            && currentStreak > previousBest
            && currentStreak > lastCelebrated
    }

    /// Longest consecutive-day run of focus days in `history`, ignoring rows on
    /// or after `todayStart` (today is neutral: an in-progress day must never
    /// inflate the previous best). Rows without a completed session don't count.
    /// DST-safe: day keys are start-of-day values built with the supplied calendar.
    static func previousBestExcludingToday(
        from history: [DailyStatsDTO],
        todayStart: Date,
        calendar: Calendar = .current
    ) -> Int {
        let pastFocusDays = history
            .filter { $0.sessionsCompleted > 0 && $0.date < todayStart }
            .map { calendar.startOfDay(for: $0.date) }
            .sorted()

        guard !pastFocusDays.isEmpty else { return 0 }

        var best = 1
        var current = 1
        for i in 1..<pastFocusDays.count {
            if let next = calendar.date(byAdding: .day, value: 1, to: pastFocusDays[i - 1]),
               calendar.isDate(next, inSameDayAs: pastFocusDays[i]) {
                current += 1
                best = max(best, current)
            } else {
                current = 1
            }
        }
        return best
    }
}
