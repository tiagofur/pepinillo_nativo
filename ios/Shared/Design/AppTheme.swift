// AppTheme.swift
// Pepinillo — Deep Work Companion for Apple
//
// Theme definitions: per-mode accent colors, palette names.
// Inject via .environment(\.appTheme, theme) at the root view.

import SwiftUI

// MARK: - Theme

struct AppTheme: Sendable {
    let name: String
    let displayName: String

    let pomodoroColor: Color
    let flowtimeColor: Color
    let timeBlockColor: Color
    let stopwatchColor: Color
    let streakColor: Color

    /// Returns the accent color for the given focus mode.
    func color(for mode: FocusMode) -> Color {
        switch mode {
        case .pomodoro:  return pomodoroColor
        case .flowtime:  return flowtimeColor
        case .timeBlock: return timeBlockColor
        case .stopwatch: return stopwatchColor
        }
    }

    /// Returns the accent color adjusted for the current phase (calmer during breaks).
    func color(for mode: FocusMode, phase: FocusPhase) -> Color {
        let base = color(for: mode)
        return phase.isBreak ? base.breakVariant(for: phase) : base
    }

    /// Gradient for the timer ring progress arc.
    func ringGradient(for mode: FocusMode) -> AngularGradient {
        let c = color(for: mode)
        return AngularGradient(
            colors: [c.opacity(0.4), c],
            center: .center,
            startAngle: .degrees(0),
            endAngle: .degrees(360)
        )
    }

    /// Gradient for the timer ring, adjusted for break phases.
    func ringGradient(for mode: FocusMode, phase: FocusPhase) -> AngularGradient {
        let c = color(for: mode, phase: phase)
        return AngularGradient(
            colors: [c.opacity(0.4), c],
            center: .center,
            startAngle: .degrees(0),
            endAngle: .degrees(360)
        )
    }
}

// MARK: - Built-in Themes

extension AppTheme {

    static let classic = AppTheme(
        name: "default",
        displayName: String(localized: "Classic"),
        pomodoroColor: Color(red: 0.91, green: 0.30, blue: 0.24),   // tomato red
        flowtimeColor: Color(red: 0.20, green: 0.53, blue: 0.92),   // ocean blue
        timeBlockColor: Color(red: 0.56, green: 0.27, blue: 0.87),  // deep purple
        stopwatchColor: Color(red: 0.18, green: 0.72, blue: 0.44),  // emerald
        streakColor: Color(red: 1.00, green: 0.60, blue: 0.10)      // amber
    )

    static let forest = AppTheme(
        name: "forest",
        displayName: String(localized: "Forest"),
        pomodoroColor: Color(red: 0.18, green: 0.55, blue: 0.23),
        flowtimeColor: Color(red: 0.13, green: 0.41, blue: 0.29),
        timeBlockColor: Color(red: 0.34, green: 0.56, blue: 0.20),
        stopwatchColor: Color(red: 0.52, green: 0.71, blue: 0.30),
        streakColor: Color(red: 0.60, green: 0.78, blue: 0.15)
    )

    static let ocean = AppTheme(
        name: "ocean",
        displayName: String(localized: "Ocean"),
        pomodoroColor: Color(red: 0.00, green: 0.51, blue: 0.79),
        flowtimeColor: Color(red: 0.05, green: 0.67, blue: 0.80),
        timeBlockColor: Color(red: 0.12, green: 0.36, blue: 0.71),
        stopwatchColor: Color(red: 0.00, green: 0.74, blue: 0.83),
        streakColor: Color(red: 0.00, green: 0.80, blue: 0.95)
    )

    static let sunset = AppTheme(
        name: "sunset",
        displayName: String(localized: "Sunset"),
        pomodoroColor: Color(red: 0.93, green: 0.36, blue: 0.15),
        flowtimeColor: Color(red: 0.96, green: 0.63, blue: 0.10),
        timeBlockColor: Color(red: 0.80, green: 0.25, blue: 0.48),
        stopwatchColor: Color(red: 0.96, green: 0.76, blue: 0.22),
        streakColor: Color(red: 1.00, green: 0.70, blue: 0.12)
    )

    // All available themes
    static let all: [AppTheme] = [.classic, .forest, .ocean, .sunset]

    static func named(_ name: String) -> AppTheme {
        all.first { $0.name == name } ?? .classic
    }
}

// MARK: - Environment Key

private struct AppThemeKey: EnvironmentKey {
    static let defaultValue: AppTheme = .classic
}

extension EnvironmentValues {
    var appTheme: AppTheme {
        get { self[AppThemeKey.self] }
        set { self[AppThemeKey.self] = newValue }
    }
}
