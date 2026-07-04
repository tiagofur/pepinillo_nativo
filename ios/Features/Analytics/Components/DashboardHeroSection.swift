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
    var streakProtectionApplied: Bool = false

    @Environment(\.appTheme) private var theme
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        Group {
            if sizeClass == .compact {
                compactBody
            } else {
                regularBody
            }
        }
        .padding(20)
        .pepinilloGlass(cornerRadius: GlassCornerRadius.hero)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(String(localized: "dashboard.hero.group.label", defaultValue: "Today's Stats"))
    }

    private var compactBody: some View {
        VStack(alignment: .leading, spacing: 20) {
            streakRow
            
            Divider()
                .opacity(0.1)

            HStack(spacing: 12) {
                heroMetric(
                    icon: "checkmark.circle",
                    value: "\(sessionsCompleted)",
                    label: String(localized: "sessions"),
                    color: .accentColor
                )
                .frame(maxWidth: .infinity)

                heroMetric(
                    icon: "clock.fill",
                    value: formattedFocusTime,
                    label: String(localized: "focused"),
                    color: .teal
                )
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var regularBody: some View {
        HStack(spacing: 18) {
            streakRow

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
    }

    private var streakRow: some View {
        HStack(spacing: 18) {
            ZStack(alignment: .bottomTrailing) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(theme.streakColor)
                    .frame(width: 58, height: 58)
                    .background(theme.streakColor.opacity(0.12), in: Circle())

                if streakProtectionApplied {
                    Image(systemName: "shield.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 22, height: 22)
                        .background(theme.streakColor, in: Circle())
                        .offset(x: 2, y: 2)
                        .accessibilityHidden(true)
                }
            }
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

                if streakProtectionApplied {
                    Text(String(localized: "streak.protection.caption",
                                defaultValue: "Streak protected · Pro skip used"))
                        .font(.caption)
                        .foregroundStyle(.blue)
                        .accessibilityLabel(String(localized: "streak.protection.accessibility",
                                                   defaultValue: "Streak protected by Pro skip"))
                } else {
                    Text(streakDays > 0
                         ? String(localized: "Keep the chain alive today.")
                         : String(localized: "Start one focused session today."))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
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
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3.weight(.semibold))
                .foregroundStyle(color)
                .frame(width: 38, height: 38)
                .background(color.opacity(0.12), in: Circle())
                .accessibilityHidden(true)
            
            VStack(alignment: .leading, spacing: 0) {
                Text(value)
                    .font(NumericFont.heroStat(size: 24))
                    .foregroundStyle(.primary)
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
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
