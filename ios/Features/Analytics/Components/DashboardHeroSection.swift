// DashboardHeroSection.swift
// Pepinillo — Deep Work Companion for Apple
//
// Shared hero section: streak, sessions, and focus time stat cards.
// Platform-agnostic — renders on iPhone, iPad, Mac Catalyst.
// Used by DashboardView (compact) and AnalyticsView (regular).

import SwiftUI

/// Top hero row showing streak, sessions completed, and total focus time.
/// Accepts plain values so no TCA store is needed at the call site —
/// the parent extracts what it needs and passes it down.
struct DashboardHeroSection: View {
    let streakDays: Int
    let sessionsCompleted: Int
    let totalFocusMinutes: Int

    @Environment(\.appTheme) private var theme

    var body: some View {
        HStack(spacing: 12) {
            HeroStatCard(
                icon: "flame.fill",
                value: streakDays > 0 ? "\(streakDays)" : "—",
                label: String(localized: "day streak"),
                color: theme.streakColor
            )
            .accessibilityElement(children: .combine)
            .accessibilityLabel(
                streakDays > 0
                    ? String(localized: "dashboard.hero.streak.label", defaultValue: "Streak: \(streakDays) days")
                    : String(localized: "dashboard.hero.streak.none", defaultValue: "No streak yet")
            )

            HeroStatCard(
                icon: "brain.head.profile",
                value: "\(sessionsCompleted)",
                label: String(localized: "sessions"),
                color: .accentColor
            )
            .accessibilityElement(children: .combine)
            .accessibilityLabel(
                String(localized: "dashboard.hero.sessions.label", defaultValue: "\(sessionsCompleted) sessions completed")
            )

            HeroStatCard(
                icon: "clock.fill",
                value: formattedFocusTime,
                label: String(localized: "focused"),
                color: .teal
            )
            .accessibilityElement(children: .combine)
            .accessibilityLabel(
                String(localized: "dashboard.hero.focused.label", defaultValue: "Focused: \(formattedFocusTime)")
            )
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(String(localized: "dashboard.hero.group.label", defaultValue: "Today's Stats"))
    }

    // MARK: - Helpers

    private var formattedFocusTime: String {
        if totalFocusMinutes >= 60 {
            let hours = totalFocusMinutes / 60
            let mins  = totalFocusMinutes % 60
            return mins > 0 ? "\(hours)h\(mins)m" : "\(hours)h"
        }
        return "\(totalFocusMinutes)m"
    }
}

// MARK: - Single Stat Card

struct HeroStatCard: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
                .accessibilityHidden(true)
            Text(value)
                .font(.title2.weight(.bold))
                .foregroundStyle(.primary)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .pepinilloGlass(cornerRadius: 14)
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Hero Section") {
    DashboardHeroSection(
        streakDays: 7,
        sessionsCompleted: 42,
        totalFocusMinutes: 185
    )
    .padding()
}
#endif
