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
        HStack(spacing: 18) {
            Image(systemName: "flame.fill")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(theme.streakColor)
                .frame(width: 58, height: 58)
                .background(theme.streakColor.opacity(0.12), in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("\(streakDays)")
                        .font(NumericFont.heroStat(size: 38))
                        .foregroundStyle(.primary)
                        .contentTransition(.numericText())
                    Text(String(localized: "day streak"))
                        .font(.headline)
                        .foregroundStyle(.primary)
                }

                Text(streakDays > 0
                     ? String(localized: "Keep the chain alive today.")
                     : String(localized: "Start one focused session today."))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 12)

            HStack(spacing: 10) {
                heroMetric(
                    icon: "checkmark.circle",
                    value: "\(sessionsCompleted)",
                    label: String(localized: "sessions"),
                    color: .accentColor
                )
                heroMetric(
                    icon: "clock.fill",
                    value: formattedFocusTime,
                    label: String(localized: "focused"),
                    color: .teal
                )
            }
        }
        .padding(20)
        .pepinilloGlass(cornerRadius: GlassCornerRadius.hero)
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

    private func heroMetric(icon: String, value: String, label: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(color)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 0) {
                Text(value)
                    .font(NumericFont.inline())
                    .foregroundStyle(.primary)
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(.quaternary.opacity(0.6), in: Capsule())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label), \(value)")
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
                .contentTransition(.symbolEffect(.replace))
                .accessibilityHidden(true)
            Text(value)
                .font(NumericFont.heroStat())
                .foregroundStyle(.primary)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .pepinilloGlass(cornerRadius: GlassCornerRadius.tile)
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
