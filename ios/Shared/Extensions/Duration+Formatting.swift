// Duration+Formatting.swift
// Pepinillo — Deep Work Companion for Apple
//
// Human-readable time formatting for the UI.

import Foundation

extension TimeInterval {
    /// "25:00" or "1:30:00" format
    var timerFormatted: String {
        let total = Int(max(0, self))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }

    /// "2h 15m" or "45m" or "30s" — for stats
    var humanReadable: String {
        let total = Int(max(0, self))
        let hours = total / 3600
        let minutes = (total % 3600) / 60

        if hours > 0 && minutes > 0 {
            return "\(hours)h \(minutes)m"
        } else if hours > 0 {
            return "\(hours)h"
        } else if minutes > 0 {
            return "\(minutes)m"
        } else {
            return "\(total)s"
        }
    }

    /// "2.5 hours" or "45 minutes" — for accessibility
    var accessibilityFormatted: String {
        let total = Int(max(0, self))
        let hours = total / 3600
        let minutes = (total % 3600) / 60

        if hours > 0 {
            let h = Double(total) / 3600.0
            return String(format: "%.1f hours", h)
        } else {
            return "\(minutes) minutes"
        }
    }
}
