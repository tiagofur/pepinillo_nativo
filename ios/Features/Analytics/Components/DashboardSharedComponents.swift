// DashboardSharedComponents.swift
// Pepinillo — Deep Work Companion for Apple
//
// Shared dashboard / analytics UI primitives used by:
//   • DashboardView (responsive main dashboard)
//   • DashboardStatCards (SummaryCard)
//   • DashboardChartsContent (ModeShareRow, PatternCard, StreakCard)

import SwiftUI
import ComposableArchitecture

// MARK: - Summary Card (used by DashboardStatCards)

struct SummaryCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
                .accessibilityHidden(true)
            Text(value)
                .font(NumericFont.kpi())
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .pepinilloGlass(cornerRadius: GlassCornerRadius.card)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(value)")
    }
}

// MARK: - Mode Share Row (shared by DashboardChartsContent)

struct ModeShareRow: View {
    let share: AnalyticsFeature.State.ModeShare
    let theme: AppTheme

    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Text(share.mode.icon)
                    .accessibilityHidden(true)
                Text(share.mode.displayName)
                    .font(.subheadline)
                Spacer()
                Text("\(share.minutes)m")
                    .font(NumericFont.inline())
                    .foregroundStyle(.secondary)
                Text("\(Int(share.percentage * 100))%")
                    .font(NumericFont.inline())
                    .frame(width: 40, alignment: .trailing)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.secondary.opacity(0.15))
                        .frame(height: 6)
                    Capsule()
                        .fill(theme.color(for: share.mode))
                        .frame(width: geo.size.width * share.percentage, height: 6)
                }
            }
            .frame(height: 6)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(share.mode.displayName), \(share.minutes) minutes, \(Int(share.percentage * 100)) percent")
    }
}

// MARK: - Pattern Card (shared by DashboardChartsContent)

struct PatternCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
                .accessibilityHidden(true)
            Text(value)
                .font(NumericFont.kpi())
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .padding(.horizontal, 8)
        .pepinilloGlass(cornerRadius: GlassCornerRadius.tile)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value)")
    }
}

// MARK: - Streak Card (shared by DashboardChartsContent)

struct StreakCard: View {
    let title: String
    let days: Int
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.largeTitle)
                .foregroundStyle(color)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(String(localized: "\(days) days"))
                    .font(NumericFont.kpi())
            }
            Spacer()
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .pepinilloGlass(cornerRadius: GlassCornerRadius.card)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title) streak, \(days) days")
    }
}

// MARK: - Loading Placeholder

struct AnalyticsPlaceholder: View {
    var body: some View {
        VStack(spacing: 20) {
            // Summary cards placeholder
            HStack(spacing: 12) {
                ForEach(0..<3, id: \.self) { _ in
                    VStack(spacing: 8) {
                        Text("00h 00m")
                            .font(.title3.weight(.bold))
                        Text("Focus Time")
                            .font(.caption)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(16)
                    .pepinilloGlass(cornerRadius: GlassCornerRadius.card)
                }
            }

            // Chart placeholder
            RoundedRectangle(cornerRadius: 16)
                .fill(.regularMaterial)
                .frame(height: 200)

            // Pattern cards placeholder
            HStack(spacing: 12) {
                ForEach(0..<2, id: \.self) { _ in
                    VStack(spacing: 8) {
                        Text("9 AM - 12 PM")
                            .font(.subheadline.weight(.bold))
                        Text("Peak Hours")
                            .font(.caption)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(16)
                    .pepinilloGlass(cornerRadius: GlassCornerRadius.card)
                }
            }
        }
    }
}
