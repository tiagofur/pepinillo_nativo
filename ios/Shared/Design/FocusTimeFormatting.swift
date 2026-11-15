// FocusTimeFormatting.swift
// Pepinillo — Deep Work Companion for Apple
//
// Single source for the compact focus-time notation ("1h 45m", "2h", "45m")
// used across stat surfaces. Previously three private copies diverged:
// DashboardHeroSection, WatchTimerView, and the Focus companion card even
// showed raw minutes.

import Foundation

enum FocusTimeFormatting {
    /// Compact "1h 45m" / "2h" / "45m" form for glanceable stat values.
    static func compact(_ minutes: Int) -> String {
        if minutes >= 60 {
            let hours = minutes / 60
            let mins = minutes % 60
            return mins > 0 ? "\(hours)h\(mins)m" : "\(hours)h"
        }
        return "\(minutes)m"
    }
}
