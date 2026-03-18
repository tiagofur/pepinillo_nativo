// WeeklyReviewView.swift
// Pepinillo — Deep Work Companion for Apple
//
// Weekly Review sheet: compares current week vs previous, shows trends,
// dominant mode, best day, and per-day breakdown.
// Presented from AnalyticsView toolbar button.

import SwiftUI
import Charts
import ComposableArchitecture

struct WeeklyReviewView: View {
    @Bindable var store: StoreOf<WeeklyReviewFeature>
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
                        weekChart
                        dominantModeCard
                        bestDayCard
                        modeBreakdown
                        streakCard
                    }
                    .padding(16)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle(String(localized: "Weekly Review"))
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
            TrendCard(
                title: String(localized: "Focus Time"),
                value: formatMinutes(store.currentWeekMinutes),
                delta: store.minutesDelta,
                deltaLabel: "\(abs(store.minutesDelta))m",
                trend: store.minutesTrend,
                color: theme.pomodoroColor
            )
            TrendCard(
                title: String(localized: "Sessions"),
                value: "\(store.currentWeekSessions)",
                delta: store.sessionsDelta,
                deltaLabel: "\(abs(store.sessionsDelta))",
                trend: store.sessionsTrend,
                color: theme.flowtimeColor
            )
        }
    }

    // MARK: - Week Bar Chart

    private var weekChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "This Week"))
                .font(.headline)

            Chart {
                ForEach(store.dailyBreakdown) { day in
                    BarMark(
                        x: .value("Day", day.dayName),
                        y: .value("Minutes", day.minutes)
                    )
                    .foregroundStyle(theme.pomodoroColor.gradient)
                    .cornerRadius(4)
                }
            }
            .chartYAxis {
                AxisMarks { _ in
                    AxisValueLabel()
                    AxisGridLine()
                }
            }
            .frame(height: 160)
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Dominant Mode

    private var dominantModeCard: some View {
        Group {
            if let mode = store.currentWeekDominantMode {
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

    // MARK: - Best Day

    private var bestDayCard: some View {
        Group {
            if let dayName = store.bestDayName, store.bestDayMinutes > 0 {
                HStack(spacing: 12) {
                    Image(systemName: "star.fill")
                        .font(.largeTitle)
                        .foregroundStyle(.yellow)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(String(localized: "Best Day"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(dayName) — \(formatMinutes(store.bestDayMinutes))")
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

    // MARK: - Streak

    private var streakCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "flame.fill")
                .font(.largeTitle)
                .foregroundStyle(theme.streakColor)
            VStack(alignment: .leading, spacing: 2) {
                Text(String(localized: "Current Streak"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(String(localized: "\(store.currentStreakDays) days"))
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

    // MARK: - Helpers

    private func formatMinutes(_ minutes: Int) -> String {
        let h = minutes / 60
        let m = minutes % 60
        if h > 0 { return "\(h)h \(m)m" }
        return "\(m)m"
    }
}

// MARK: - Trend Card

struct TrendCard: View {
    let title: String
    let value: String
    let delta: Int
    let deltaLabel: String
    let trend: WeeklyReviewFeature.State.Trend
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
