// Date+Extensions.swift
// Pepinillo — Deep Work Companion for Apple

import Foundation

extension Date {
    /// Start of day in user's calendar.
    var startOfDay: Date {
        Calendar.current.startOfDay(for: self)
    }

    /// Whether this date is today.
    var isToday: Bool {
        Calendar.current.isDateInToday(self)
    }

    /// Returns the date N days ago.
    func daysAgo(_ days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: -days, to: self)!
    }

    /// Formatted as "Mon, Mar 11"
    var shortFormatted: String {
        formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
    }

    /// Week of year for grouping analytics.
    var weekOfYear: Int {
        Calendar.current.component(.weekOfYear, from: self)
    }
}
