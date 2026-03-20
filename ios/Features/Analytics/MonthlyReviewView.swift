// MonthlyReviewView.swift
// Pepinillo — Deep Work Companion for Apple
//
// Monthly Review sheet: compares current month vs previous, shows trends,
// dominant mode, best week, top tasks, and mode distribution.
// Presented from AnalyticsView toolbar button.

import SwiftUI
import ComposableArchitecture

struct MonthlyReviewView: View {
    @Bindable var store: StoreOf<MonthlyReviewFeature>
    @Environment(\.appTheme) private var theme
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                if store.isLoading {
                    ProgressView()
                        .padding(.top, 60)
                } else {
                    VStack(spacing: 20) {
                        comparisonCards
                        completionRateCard
                        bestWeekCard
                        topTasksSection
                        dominantModeCard
                        modeBreakdown
                    }
                    .padding(16)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle(String(localized: "Monthly Review"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "Done")) { dismiss() }
                }
            }
            .onAppear { store.send(.onAppear) }
        }
    }

    // MARK: - Comparison Cards

    private var comparisonCards: some View {
        HStack(spacing: 12) {
            MonthlyTrendCard(
                title: String(localized: "Focus Time"),
                value: formatMinutes(store.currentMonthMinutes),
                delta: store.minutesDelta,
                deltaLabel: "\(abs(store.minutesDelta))m",
                trend: store.minutesTrend,
                color: theme.pomodoroColor
            )
            MonthlyTrendCard(
                title: String(localized: "Sessions"),
                value: "\(store.currentMonthSessions)",
                delta: store.sessionsDelta,
                deltaLabel: "\(abs(store.sessionsDelta))",
                trend: store.sessionsTrend,
                color: theme.flowtimeColor
            )
        }
    }

    // MARK: - Completion Rate

    private var completionRateCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.largeTitle)
                .foregroundStyle(.green)
            VStack(alignment: .leading, spacing: 2) {
                Text(String(localized: "Completion Rate"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("\(Int(store.completionRate * 100))%")
                    .font(.title3)
                    .fontWeight(.bold)
            }
            Spacer()
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Best Week

    private var bestWeekCard: some View {
        Group {
            if let weekLabel = store.bestWeekLabel, store.bestWeekMinutes > 0 {
                HStack(spacing: 12) {
                    Image(systemName: "star.fill")
                        .font(.largeTitle)
                        .foregroundStyle(.yellow)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(String(localized: "Best Week"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(weekLabel) — \(formatMinutes(store.bestWeekMinutes))")
                            .font(.title3)
                            .fontWeight(.bold)
                    }
                    Spacer()
                }
                .padding(16)
                .frame(maxWidth: .infinity)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
        }
    }

    // MARK: - Top Tasks

    private var topTasksSection: some View {
        Group {
            if !store.topTasks.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text(String(localized: "Top Tasks"))
                        .font(.headline)

                    ForEach(store.topTasks) { task in
                        HStack {
                            Text(task.title)
                                .font(.subheadline)
                                .lineLimit(1)
                            Spacer()
                            Text(formatMinutes(task.minutes))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(16)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
        }
    }

    // MARK: - Dominant Mode

    private var dominantModeCard: some View {
        Group {
            if let mode = store.currentMonthDominantMode {
                HStack(spacing: 12) {
                    Text(mode.icon)
                        .font(.largeTitle)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(String(localized: "Dominant Mode"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(mode.displayName)
                            .font(.title3)
                            .fontWeight(.bold)
                    }
                    Spacer()
                }
                .padding(16)
                .frame(maxWidth: .infinity)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
        }
    }

    // MARK: - Mode Breakdown

    private var modeBreakdown: some View {
        Group {
            if !store.modeDistribution.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text(String(localized: "Mode Distribution"))
                        .font(.headline)

                    ForEach(store.modeDistribution) { item in
                        HStack {
                            Text(item.mode.icon)
                            Text(item.mode.displayName)
                                .font(.subheadline)
                            Spacer()
                            Text(formatMinutes(item.minutes))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(16)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
        }
    }

    // MARK: - Helpers

    private func formatMinutes(_ minutes: Int) -> String {
        let h = minutes / 60
        let m = minutes % 60
        if h > 0 { return "\(h)h \(m)m" }
        return "\(m)m"
    }
}

// MARK: - Monthly Trend Card

struct MonthlyTrendCard: View {
    let title: String
    let value: String
    let delta: Int
    let deltaLabel: String
    let trend: MonthlyReviewFeature.State.Trend
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 4) {
                Image(systemName: trendIcon)
                    .font(.caption2)
                Text(delta == 0 ? "—" : (delta > 0 ? "+\(deltaLabel)" : "-\(deltaLabel)"))
                    .font(.caption2)
            }
            .foregroundStyle(trendColor)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var trendIcon: String {
        switch trend {
        case .up:      return "arrow.up.right"
        case .down:    return "arrow.down.right"
        case .neutral: return "minus"
        }
    }

    private var trendColor: Color {
        switch trend {
        case .up:      return .green
        case .down:    return .red
        case .neutral: return .secondary
        }
    }
}
