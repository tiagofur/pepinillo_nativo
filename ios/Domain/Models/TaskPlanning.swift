// TaskPlanning.swift
// Pepinillo — Deep Work Companion for Apple
//
// Single «Hoy» rule shared by every Apple surface (issue #991 S2/S3): the
// Plan lists, widgets, watch list, complications, Siri and the Mac Today
// panel all resolve buckets here. The rule is asserted against
// contracts/fixtures/task-planning-cases-991.json — a shared case table that
// the Android and web suites decode too.

import Foundation

/// Where an active task lives in Plan. `.completed` exists for fixture
/// completeness; most callers filter completed tasks before bucketing.
public enum TaskPlanningBucket: Equatable, Sendable {
    /// «Hoy» — planned today or earlier (S6 keeps past plans visible as
    /// `postponed`), or due today or overdue.
    case today(postponed: Bool)
    /// «Próximas» — first planned or due day is strictly in the future.
    case upcoming
    /// «Bandeja» — no planned date and no due date.
    case inbox
    case completed
}

/// Pure resolver for the unified «Hoy» rule (issue #991 S2).
///
/// `plannedDate` is a local calendar day stored as the start of that day.
/// `scheduledForToday` is the legacy pre-#991 boolean that still travels on
/// the wire (S9) and still exists in older stores: it acts as a sync shim
/// only where the new semantics don't speak (no planned date, or a future
/// one). A past planned date always keeps its S6 postponement.
public enum TaskPlanning {

    /// The bucket a task belongs to right now.
    public static func bucket(
        plannedDate: Date?,
        dueDate: Date?,
        scheduledForToday: Bool = false,
        isCompleted: Bool,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> TaskPlanningBucket {
        if isCompleted { return .completed }

        // Legacy shim: an older cohort's "in today's list" flag keeps the
        // task in «Hoy» until a written planned date (past plans keep the
        // S6 badge) or the physical backfill replaces it.
        if scheduledForToday,
           plannedDate == nil || isFutureDay(plannedDate!, now: now, calendar: calendar) {
            return .today(postponed: false)
        }

        if let plannedDate, isOnOrBefore(plannedDate, now, calendar: calendar) {
            return .today(postponed: !calendar.isDate(plannedDate, inSameDayAs: now))
        }
        if let dueDate, isOnOrBefore(dueDate, now, calendar: calendar) {
            return .today(postponed: false)
        }
        return (plannedDate != nil || dueDate != nil) ? .upcoming : .inbox
    }

    /// Canonical storage form for a planned date: start of the local day.
    /// Recurrence (S8) and every write path normalize through this.
    public static func plannedDay(_ date: Date, calendar: Calendar = .current) -> Date {
        calendar.startOfDay(for: date)
    }

    // MARK: - Day comparisons

    static func isOnOrBefore(_ date: Date, _ reference: Date, calendar: Calendar) -> Bool {
        calendar.compare(date, to: reference, toGranularity: .day) != .orderedDescending
    }

    static func isFutureDay(_ date: Date, now: Date, calendar: Calendar) -> Bool {
        calendar.compare(date, to: now, toGranularity: .day) == .orderedDescending
    }
}
