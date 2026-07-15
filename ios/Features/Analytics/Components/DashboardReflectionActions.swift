// DashboardReflectionActions.swift
// Pepinillo — Deep Work Companion for Apple
//
// Reflection action cards: Weekly Review and Monthly Review entry points.
// Platform-agnostic — used by both DashboardView and AnalyticsView.

import SwiftUI

/// Two tappable cards that open the Weekly Review and Monthly Review sheets.
/// Accepts plain closures and optional live preview strings computed from real data.
struct DashboardReflectionActions: View {
    let onWeeklyReview: () -> Void
    let onMonthlyReview: () -> Void
    /// If set, replaces the generic subtitle with a data-driven preview line.
    var weeklyPreview: String? = nil
    var monthlyPreview: String? = nil

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: SpacingTokens.base)], spacing: SpacingTokens.base) {
            ReflectionCard(
                icon: "calendar.badge.clock",
                title: String(localized: "Weekly Review"),
                subtitle: weeklyPreview ?? String(localized: "Data & AI insights for your week"),
                color: .orange,
                action: onWeeklyReview
            )
            .accessibilityHint(String(localized: "dashboard.reflection.weekly.hint", defaultValue: "Opens your weekly productivity report"))

            ReflectionCard(
                icon: "calendar.badge.checkmark",
                title: String(localized: "Monthly Review"),
                subtitle: monthlyPreview ?? String(localized: "Data & AI insights for your month"),
                color: .purple,
                action: onMonthlyReview
            )
            .accessibilityHint(String(localized: "dashboard.reflection.monthly.hint", defaultValue: "Opens your monthly productivity report"))
        }
    }
}

// MARK: - Single Reflection Card

struct ReflectionCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(color)
                    .frame(width: 36)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            .padding(SpacingTokens.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.quaternary.opacity(0.55), in: RoundedRectangle(cornerRadius: GlassCornerRadius.card, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: GlassCornerRadius.card, style: .continuous)
                    .stroke(.secondary.opacity(0.12), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Reflection Actions") {
    DashboardReflectionActions(
        onWeeklyReview: {},
        onMonthlyReview: {}
    )
    .padding()
}
#endif
