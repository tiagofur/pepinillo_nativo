// FocusGaps.swift
// Pepinillo — Deep Work Companion for Apple
//
// Issue #992 (S2): the pure «Huecos de hoy» engine — where does a focus
// block fit between today's calendar events? No EventKit here: the caller
// maps EKEvents into the lightweight DayEvent below, so the whole rule is
// testable against contracts/fixtures/focus-gaps-cases-992.json without a
// database or a store.

import Foundation

/// A calendar event reduced to what gap math needs.
public struct DayEvent: Equatable, Sendable {
    public let start: Date
    public let end: Date
    public let isAllDay: Bool

    public init(start: Date, end: Date, isAllDay: Bool = false) {
        self.start = start
        self.end = end
        self.isAllDay = isAllDay
    }
}

/// One free interval between two merged busy blocks of today.
public struct FocusGap: Equatable, Identifiable, Sendable {
    /// The gap start, already truncated to the decision window.
    public let start: Date
    /// The gap end (= start of the next busy block).
    public let end: Date

    public init(start: Date, end: Date) {
        self.start = start
        self.end = end
    }

    public var id: Date { start }

    /// Whole minutes the gap lasts (floored — 24:59 never sells as 25).
    public var durationMinutes: Int {
        Int(end.timeIntervalSince(start) / 60)
    }
}

public enum FocusGaps {

    /// Minimum useful block (issue S2 default): shorter slots are noise.
    public static let minimumGapMinutes = 25

    /// The card shows at most this many chips (the longest ones).
    public static let maxShown = 3

    /// TimeBlock's own ceiling — the launch path clamps to it; the engine
    /// only reports real gaps.
    public static let maxBlockMinutes = 480

    /// Compute today's focus gaps.
    ///
    /// Semantics (contracted by the shared case table):
    /// - gaps run strictly BETWEEN merged busy blocks — nothing before the
    ///   first block or after the last one counts, so an empty or
    ///   single-block day has no gaps (issue S1's empty-calendar rule);
    /// - the decision window starts at `max(now, startOfDay(now))`: gaps are
    ///   truncated to it and dropped when the remainder falls under
    ///   `minimumGapMinutes`;
    /// - overlapping and touching events merge into one busy block; a
    ///   zero-duration event is no block at all;
    /// - any all-day event makes the whole day busy;
    /// - at most `maxShown` gaps survive: the longest ones, then ordered by
    ///   start for display.
    public static func computeGaps(
        events: [DayEvent],
        now: Date,
        calendar: Calendar = .current,
        minimumGapMinutes: Int = FocusGaps.minimumGapMinutes,
        maxShown: Int = FocusGaps.maxShown
    ) -> [FocusGap] {
        let dayStart = calendar.startOfDay(for: now)
        let windowStart = max(now, dayStart)

        if events.contains(where: \.isAllDay) {
            return []  // the whole day is spoken for (S2)
        }

        // Merge overlapping/touching non-empty busy blocks.
        let busy = events
            .filter { $0.end > $0.start }
            .map { ($0.start, $0.end) }
            .sorted { $0.0 < $1.0 }
        var merged: [(Date, Date)] = []
        for (start, end) in busy {
            if let last = merged.last, start <= last.1 {
                if end > last.1 {
                    merged[merged.count - 1].1 = end
                }
            } else {
                merged.append((start, end))
            }
        }
        guard merged.count >= 2 else { return [] }

        // Free intervals strictly between consecutive busy blocks.
        var gaps: [FocusGap] = []
        for i in 0..<(merged.count - 1) {
            let start = max(merged[i].1, windowStart)
            let end = merged[i + 1].0
            let gap = FocusGap(start: start, end: end)
            if gap.durationMinutes >= minimumGapMinutes {
                gaps.append(gap)
            }
        }

        // The longest `maxShown` survive, displayed by start.
        let survivors = gaps
            .sorted { $0.durationMinutes > $1.durationMinutes }
            .prefix(maxShown)
        return survivors.sorted { $0.start < $1.start }
    }
}
