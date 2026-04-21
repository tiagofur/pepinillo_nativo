// AnalyticsView.swift
// Pepinillo — Deep Work Companion for Apple
//
// Analytics dashboard — iPad/Mac primary view.
// Composes shared components from Analytics/Components/:
//   • DashboardHeroSection   — streak + sessions + focus time
//   • DashboardStatCards     — period summary stat row
//   • DashboardChartsContent — bar chart + patterns + breakdown + streaks
//
// Layout strategy:
//   • compact (iPhone or narrow iPad):   single-column VStack (same as DashboardView)
//   • regular (full-size iPad, Mac):     hero full-width, then 2-column LazyVGrid
//     so stat cards + charts split into two columns on wide canvases.

import SwiftUI
import ComposableArchitecture

struct AnalyticsView: View {
    @Bindable var store: StoreOf<AnalyticsFeature>
    @Environment(\.appTheme) private var theme
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Period picker — always full-width at the top
                    periodPicker
                        .padding(.horizontal, 16)

                    if store.isLoading {
                        AnalyticsPlaceholder()
                            .redacted(reason: .placeholder)
                            .padding(.horizontal, 16)
                    } else if store.chartData.isEmpty && store.sessionsCompleted == 0 {
                        ContentUnavailableView(
                            String(localized: "No Data Yet"),
                            systemImage: "chart.bar",
                            description: Text(String(localized: "Complete your first focus session to see your analytics here."))
                        )
                        .padding(.top, 40)
                    } else {
                        content
                    }
                }
                .padding(.bottom, 32)
            }
            .refreshable { store.send(.onAppear) }
            .navigationTitle(String(localized: "Analytics"))
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    if AppConfig.aiInsightsEnabled {
                        Menu {
                            Button {
                                store.send(.aiReportTapped(.week))
                            } label: {
                                Label(String(localized: "Weekly AI Report"), systemImage: "sparkles")
                            }
                            Button {
                                store.send(.aiReportTapped(.month))
                            } label: {
                                Label(String(localized: "Monthly AI Report"), systemImage: "sparkles")
                            }
                        } label: {
                            Label(String(localized: "AI Report"), systemImage: "sparkles")
                        }
                    }
                    Button {
                        store.send(.weeklyReviewTapped)
                    } label: {
                        Label(String(localized: "Weekly Review"), systemImage: "calendar.badge.clock")
                    }
                    .accessibilityHint(String(localized: "dashboard.reflection.weekly.hint", defaultValue: "Opens your weekly productivity report"))

                    Button {
                        store.send(.monthlyReviewTapped)
                    } label: {
                        Label(String(localized: "Monthly Review"), systemImage: "calendar.badge.checkmark")
                    }
                    .accessibilityHint(String(localized: "dashboard.reflection.monthly.hint", defaultValue: "Opens your monthly productivity report"))
                }
            }
            .sheet(item: $store.scope(state: \.weeklyReview, action: \.weeklyReview)) { weeklyStore in
                WeeklyReviewView(store: weeklyStore, isProUser: store.isProUser, analyticsStore: store)
            }
            .sheet(item: $store.scope(state: \.monthlyReview, action: \.monthlyReview)) { monthlyStore in
                MonthlyReviewView(store: monthlyStore, isProUser: store.isProUser, analyticsStore: store)
            }
            .onAppear { store.send(.onAppear) }
        }
    }

    // MARK: - Layout

    @ViewBuilder
    private var content: some View {
        if horizontalSizeClass == .regular {
            regularLayout
        } else {
            compactLayout
        }
    }

    /// Compact (iPhone / narrow iPad): single-column VStack — same as DashboardView.
    private var compactLayout: some View {
        VStack(spacing: 16) {
            DashboardHeroSection(
                streakDays: store.currentStreakDays,
                sessionsCompleted: store.sessionsCompleted,
                totalFocusMinutes: store.totalFocusMinutes
            )
            .padding(.horizontal, 16)

            DashboardStatCards(
                formattedTotalTime: formattedTotalTime,
                sessionsCompleted: store.sessionsCompleted,
                currentStreakDays: store.currentStreakDays
            )
            .padding(.horizontal, 16)

            DashboardChartsContent(store: store)
                .padding(.horizontal, 16)
        }
    }

    /// Regular (full-size iPad, Mac): hero full-width, content in 2-column grid.
    private var regularLayout: some View {
        VStack(spacing: 20) {
            // Hero spans the full width above the grid
            DashboardHeroSection(
                streakDays: store.currentStreakDays,
                sessionsCompleted: store.sessionsCompleted,
                totalFocusMinutes: store.totalFocusMinutes
            )
            .padding(.horizontal, 24)

            // 2-column grid: stat cards on one side, charts on the other.
            // LazyVGrid lets both columns grow vertically independently.
            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 20),
                    GridItem(.flexible(), spacing: 20)
                ],
                alignment: .top,
                spacing: 20
            ) {
                // Left column — summary stats + reflection actions
                VStack(spacing: 16) {
                    DashboardStatCards(
                        formattedTotalTime: formattedTotalTime,
                        sessionsCompleted: store.sessionsCompleted,
                        currentStreakDays: store.currentStreakDays
                    )

                    DashboardReflectionActions(
                        onWeeklyReview:  { store.send(.weeklyReviewTapped) },
                        onMonthlyReview: { store.send(.monthlyReviewTapped) }
                    )
                }

                // Right column — full charts block
                DashboardChartsContent(store: store)
            }
            .padding(.horizontal, 24)
        }
    }

    // MARK: - Period Picker

    private var periodPicker: some View {
        Picker(String(localized: "Period"), selection: Binding(
            get: { store.period },
            set: { store.send(.periodChanged($0)) }
        )) {
            ForEach(AnalyticsFeature.State.Period.allCases, id: \.self) { p in
                Text(p.displayName).tag(p)
            }
        }
        .pickerStyle(.segmented)
    }

    // MARK: - Helpers

    private var formattedTotalTime: String {
        let hours = store.totalFocusMinutes / 60
        let minutes = store.totalFocusMinutes % 60
        if hours > 0 {
            return String(localized: "\(hours)h \(minutes)m")
        }
        return String(localized: "\(minutes)m")
    }
}

// MARK: - Summary Card (used by DashboardStatCards — kept here for shared use)

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
                .font(.title3)
                .fontWeight(.bold)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
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
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("\(Int(share.percentage * 100))%")
                    .font(.subheadline)
                    .fontWeight(.semibold)
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
                .font(.title3)
                .fontWeight(.bold)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .padding(.horizontal, 8)
        .background(Color(.tertiarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
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
                    .font(.title3)
                    .fontWeight(.bold)
            }
            Spacer()
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
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
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            }

            // Chart placeholder
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
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
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            }
        }
    }
}
