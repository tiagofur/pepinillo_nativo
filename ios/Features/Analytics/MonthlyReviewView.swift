// MonthlyReviewView.swift
// Pepinillo — Deep Work Companion for Apple
//
// Monthly Review sheet with 2 tabs:
// - Data: comparisons, completion rate, best week, top tasks
// - AI Insights: productivity score, patterns, recommendations (Pepinillo+ only)
// Presented from Dashboard reflection cards.

import SwiftUI
import ComposableArchitecture

struct MonthlyReviewView: View {
    @Bindable var store: StoreOf<MonthlyReviewFeature>
    let isProUser: Bool
    let analyticsStore: StoreOf<AnalyticsFeature>

    @Environment(\.appTheme) private var theme
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab: ReviewTab = .data

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                reviewTabPicker
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                ScrollView {
                    switch selectedTab {
                    case .data:
                        dataTab
                    case .aiInsights:
                        aiInsightsTab
                    }
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

    // MARK: - Tab Picker

    private var reviewTabPicker: some View {
        Picker(String(localized: "Review Section"), selection: $selectedTab) {
            ForEach(ReviewTab.allCases, id: \.self) { tab in
                Label(tab.label, systemImage: tab.icon)
                    .tag(tab)
            }
        }
        .pickerStyle(.segmented)
        .padding(.bottom, 8)
    }

    // MARK: - Data Tab

    private var dataTab: some View {
        VStack(spacing: 20) {
            if store.isLoading {
                ProgressView()
                    .padding(.top, 60)
            } else {
                comparisonCards
                completionRateCard
                bestWeekCard
                topTasksSection
                dominantModeCard
                modeBreakdown
            }
        }
        .padding(16)
        .padding(.bottom, 32)
    }

    // MARK: - AI Insights Tab

    private var aiInsightsTab: some View {
        Group {
            if isProUser {
                AIInsightsContent(
                    period: .month,
                    analyticsStore: analyticsStore
                )
            } else {
                proRequiredOverlay
            }
        }
    }

    private var proRequiredOverlay: some View {
        VStack(spacing: 20) {
            Spacer()
                .frame(height: 40)

            Image(systemName: "sparkles")
                .font(.system(size: 48))
                .foregroundStyle(.purple)

            Text(String(localized: "AI Insights requires Pepinillo+"))
                .font(.title3.bold())

            Text(String(localized: "Get AI-powered monthly analysis with pattern detection, a productivity score, and personalized coaching."))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()
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
        .pepinilloGlass(cornerRadius: GlassCornerRadius.card)
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
                .pepinilloGlass(cornerRadius: GlassCornerRadius.card)
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
                .pepinilloGlass(cornerRadius: GlassCornerRadius.card)
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
                .pepinilloGlass(cornerRadius: GlassCornerRadius.card)
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
                .pepinilloGlass(cornerRadius: GlassCornerRadius.card)
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
        .pepinilloGlass(cornerRadius: GlassCornerRadius.card)
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
