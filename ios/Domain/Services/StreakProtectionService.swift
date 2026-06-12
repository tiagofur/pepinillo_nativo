// StreakProtectionService.swift
// Pepinillo — Deep Work Companion for Apple
//
// Pure, stateless streak computation with Pro streak-protection.
// Used by the main app and widgets alike.
//
// Algorithm
// ---------
// Walk backward from today through daily focus records (newest first).
// A day counts toward the streak if:
//   (a) it has hadFocusSession == true, OR
//   (b) it is a "protected miss" — a missed day the user is Pro, and no other
//       skip has been consumed within the preceding rolling 7-day window.
//
// "Rolling 7-day window": for each miss we check whether a skip was already
// used within the 7 days immediately before that miss (walking backward,
// "before" = an earlier date). If not, the miss is auto-covered. Max one skip
// per rolling 7-day window.
//
// The function is purely referentially transparent: same inputs → same output.
// No AppGroupDefaults writes, no SwiftData mutations.

import Foundation

// MARK: - Result type

public struct StreakResult: Equatable, Sendable {
    /// The computed streak length (with protection applied, if applicable).
    public let days: Int
    /// True if at least one skipped day was covered by Pro protection.
    public let protectionApplied: Bool

    public static let zero = StreakResult(days: 0, protectionApplied: false)
}

// MARK: - Service

public enum StreakProtectionService {

    /// Compute the current streak from a pre-built focus-by-day lookup.
    ///
    /// - Parameters:
    ///   - focusByDay: A dictionary mapping start-of-day `Date` to whether the
    ///                 user had at least one focus session on that day.
    ///   - isPro:      Whether the user has an active Pro subscription.
    ///   - today:      The calendar day to treat as "today".
    ///   - calendar:   Calendar to use for day arithmetic.
    /// - Returns: A `StreakResult` with the protected streak length and a flag
    ///            indicating whether protection was actually applied.
    ///
    /// Today-in-progress rule
    /// ----------------------
    /// If today has no focus session yet, it is **neutral** — it does not break
    /// the streak and does not consume a Pro skip. The streak is computed
    /// starting from yesterday. This matches the pre-streak-protection
    /// widget-provider algorithm (which anchored at yesterday when today had no
    /// activity). A Pro skip can only cover fully-elapsed missed days (yesterday
    /// and earlier).
    public static func computeProtectedStreak(
        focusByDay: [Date: Bool],
        isPro: Bool,
        today: Date,
        calendar: Calendar
    ) -> StreakResult {
        guard !focusByDay.isEmpty else { return .zero }

        let startOfToday = calendar.startOfDay(for: today)

        // If the user already has a session today, start the walk from today.
        // Otherwise, skip today entirely — an in-progress day is neutral.
        let todayHasFocus = focusByDay[startOfToday] ?? false
        guard let startDate = todayHasFocus
            ? Optional(startOfToday)
            : calendar.date(byAdding: .day, value: -1, to: startOfToday)
        else { return .zero }

        // Earliest calendar day that actually has a recorded focus session.
        // A Pro skip can only bridge over missed days that sit between two real
        // focus sessions — it must never extend the streak past the oldest known
        // record, because there's no evidence of a prior streak to protect.
        guard let earliestFocusDate = focusByDay
            .filter({ $0.value })
            .keys
            .min() else {
            // Zero focus history — no streak to protect.
            return .zero
        }

        var streak = 0
        var protectionApplied = false

        // lastSkipUsedDate: the date of the most recently consumed skip (if any).
        // We enforce: the next skip must be ≥ 7 calendar days before this one
        // (since we walk backward, "before" = an earlier absolute date).
        var lastSkipUsedDate: Date? = nil

        var checkDate = startDate

        for _ in 0..<730 { // Safety cap: max 2 years back
            let hadFocus = focusByDay[checkDate] ?? false

            if hadFocus {
                streak += 1
            } else if isPro && checkDate >= earliestFocusDate {
                // Determine whether we can cover this miss with a skip.
                // Only allow skipping within the span of actual focus history —
                // never speculatively extend past the oldest recorded day.
                // Today is excluded from skip eligibility (handled above by
                // anchoring the walk at yesterday when today has no activity).
                let canSkip: Bool
                if let lastSkip = lastSkipUsedDate {
                    // Days apart between the previous skip (lastSkip) and current miss
                    // (checkDate). Since lastSkip > checkDate (we're walking backward),
                    // this is a positive value.
                    let daysApart = calendar.dateComponents([.day], from: checkDate, to: lastSkip).day ?? 0
                    canSkip = daysApart >= 7
                } else {
                    canSkip = true
                }

                if canSkip {
                    streak += 1
                    protectionApplied = true
                    lastSkipUsedDate = checkDate
                } else {
                    break
                }
            } else {
                break
            }

            guard let previousDay = calendar.date(byAdding: .day, value: -1, to: checkDate) else { break }
            checkDate = previousDay
        }

        return StreakResult(days: streak, protectionApplied: protectionApplied)
    }
}
