// StreakEngine.swift
// Pepinillo — Deep Work Companion for Apple
//
// Pure streak computation with Pro streak-protection support.
//
// Design:
//   - Stateless, pure function: input is sorted active-day dates + Pro flag + today's date.
//   - Pro users get one automatic "streak skip" per rolling 7-day window:
//     a single missed day sandwiched between active days is silently bridged.
//   - Result carries a protectionApplied flag so the UI can show a subtle shield.
//   - Widget providers, app features, and watch all call the same function.

import Foundation

// MARK: - Result

/// Returned by StreakEngine for every computation.
public struct StreakResult: Sendable, Equatable {
    /// The protected streak length (days).
    public let streak: Int
    /// True when a missed day was automatically bridged via streak-protection.
    public let protectionApplied: Bool

    public init(streak: Int, protectionApplied: Bool) {
        self.streak = streak
        self.protectionApplied = protectionApplied
    }
}

// MARK: - Engine

public enum StreakEngine {

    /// Computes the current streak from a collection of active day dates.
    ///
    /// - Parameters:
    ///   - activeDays:  Collection of dates on which the user had at least one focus session.
    ///                  Dates are normalised internally — time components are ignored.
    ///   - isProUser:   When `true`, a single missed day within any rolling 7-day window
    ///                  is auto-bridged (at most once per 7-day window).
    ///   - today:       The reference date (defaults to `.now`).  Pass a fixed date in tests.
    /// - Returns:       A `StreakResult` with the final streak and a protection flag.
    public static func computeStreak(
        activeDays: some Collection<Date>,
        isProUser: Bool,
        today: Date = .now,
        calendar: Calendar = .current
    ) -> StreakResult {
        guard !activeDays.isEmpty else { return StreakResult(streak: 0, protectionApplied: false) }

        // Normalise all dates to start-of-day and deduplicate.
        let normalised = Set(activeDays.map { calendar.startOfDay(for: $0) })
        let todayStart = calendar.startOfDay(for: today)

        var streak = 0
        var protectionApplied = false
        // Track the epoch when the last skip was used (for rolling 7-day enforcement).
        var lastSkipUsedOn: Date? = nil
        var checkDate = todayStart

        // Walk backwards one day at a time from today.
        for _ in 0..<365 {
            guard let prevDay = calendar.date(byAdding: .day, value: -1, to: checkDate) else { break }

            if normalised.contains(prevDay) {
                streak += 1
                checkDate = prevDay
            } else if isProUser {
                // Candidate for streak-skip: prevDay is a miss.
                // Rules:
                //  1. The day before prevDay must be active (no double-miss bridging).
                //  2. No skip has been used within the last 7 days (rolling window from lastSkipUsedOn).
                guard let dayBeforeMiss = calendar.date(byAdding: .day, value: -1, to: prevDay),
                      normalised.contains(dayBeforeMiss) else { break }

                // Check rolling 7-day window for previous skip usage.
                if let lastSkip = lastSkipUsedOn {
                    let daysSinceLastSkip = calendar.dateComponents([.day], from: lastSkip, to: prevDay).day ?? 0
                    guard daysSinceLastSkip >= 7 else { break }
                }

                // Apply the skip: bridge the miss and continue.
                streak += 1  // count the skipped day as part of the streak
                protectionApplied = true
                lastSkipUsedOn = prevDay
                checkDate = dayBeforeMiss  // advance past the skipped day (dayBeforeMiss is active, pick it up next iteration)
            } else {
                break
            }
        }

        return StreakResult(streak: streak, protectionApplied: protectionApplied)
    }
}
