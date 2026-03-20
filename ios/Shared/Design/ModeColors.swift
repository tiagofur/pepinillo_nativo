// ModeColors.swift
// Pepinillo — Deep Work Companion for Apple
//
// Shared mode color constants used across all targets.
// Main app uses AppTheme for theming; extensions use these defaults.

import SwiftUI

enum ModeColors {
    static let pomodoro  = Color(red: 0.91, green: 0.30, blue: 0.24)
    static let flowtime  = Color(red: 0.20, green: 0.53, blue: 0.92)
    static let timeBlock = Color(red: 0.56, green: 0.27, blue: 0.87)
    static let stopwatch = Color(red: 0.18, green: 0.72, blue: 0.44)
    static let streak    = Color(red: 1.00, green: 0.60, blue: 0.10)

    static func color(for modeRawValue: String) -> Color {
        switch modeRawValue {
        case "pomodoro":  return pomodoro
        case "flowtime":  return flowtime
        case "timeBlock": return timeBlock
        case "stopwatch": return stopwatch
        case "streak":    return streak
        default:          return .blue
        }
    }

    /// Returns the mode color adjusted for the current phase string (for widgets and Live Activity).
    static func color(for modeRawValue: String, phase: String) -> Color {
        let base = color(for: modeRawValue)
        switch phase {
        case "Short Break": return base.shortBreakVariant()
        case "Long Break":  return base.longBreakVariant()
        case "Break":       return base.shortBreakVariant()
        default:            return base
        }
    }
}
