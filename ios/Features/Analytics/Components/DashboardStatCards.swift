// DashboardStatCards.swift
// Pepinillo — Deep Work Companion for Apple
//
// Three-card summary row: Focus Time, Sessions, Streak.
// Derived from the AnalyticsView summaryCards section.
// Platform-agnostic — callers can embed in any column layout.

import SwiftUI

/// A row of three summary stat cards shown below the period picker.
/// Accepts plain values to keep the component store-agnostic and testable.
struct DashboardStatCards: View {
    let formattedTotalTime: String
    let sessionsCompleted: Int
    let currentStreakDays: Int

    @Environment(\.appTheme) private var theme

    var body: some View {
        HStack(spacing: SpacingTokens.base) {
            SummaryCard(
                title: String(localized: "Focus Time"),
                value: formattedTotalTime,
                icon: "brain.head.profile",
                color: theme.pomodoroColor
            )
            SummaryCard(
                title: String(localized: "Sessions"),
                value: "\(sessionsCompleted)",
                icon: "checkmark.circle",
                color: theme.flowtimeColor
            )
            SummaryCard(
                title: String(localized: "Streak"),
                value: "\(currentStreakDays)d",
                icon: "flame.fill",
                color: theme.streakColor
            )
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Stat Cards") {
    DashboardStatCards(
        formattedTotalTime: "3h 45m",
        sessionsCompleted: 12,
        currentStreakDays: 5
    )
    .padding()
}
#endif
