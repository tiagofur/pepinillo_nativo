// DashboardView.swift
// Pepinillo — Deep Work Companion for Apple
//
// Responsive Dashboard — single source of truth for iPhone, iPad, and Mac.
// Composes shared components from Analytics/Components/:
//   • DashboardHeroSection       — streak + sessions + focus time
//   • DashboardReflectionActions — Weekly/Monthly Review entry points
//   • DashboardStatCards         — period summary stat row
//   • DashboardChartsContent     — bar chart + patterns + breakdown + streaks
//
// Layout strategy:
//   • compact (iPhone, narrow iPad): single-column VStack
//   • regular (full iPad, Mac):      hero full-width, then 2-column LazyVGrid

import SwiftUI
import ComposableArchitecture

struct DashboardView: View {
    @Bindable var store: StoreOf<AnalyticsFeature>
    @Environment(\.appTheme) private var theme
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        ZStack {
            PepinilloLiquidBackground()

            ScrollView {
                VStack(spacing: 20) {
                    periodPicker
                        .padding(.horizontal, horizontalSizeClass == .regular ? 24 : 16)

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
        }
        .background(Color.clear)
        .refreshable { store.send(.onAppear) }
        .navigationTitle(String(localized: "Dashboard"))
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
        .onAppear { store.send(.onAppear) }
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

    /// Compact (iPhone / narrow iPad): single-column VStack.
    private var compactLayout: some View {
        VStack(spacing: 20) {
            DashboardHeroSection(
                streakDays: store.currentStreakDays,
                sessionsCompleted: store.sessionsCompleted,
                totalFocusMinutes: store.totalFocusMinutes
            )
            .padding(.horizontal, 16)

            DashboardReflectionActions(
                onWeeklyReview:  { store.send(.weeklyReviewTapped) },
                onMonthlyReview: { store.send(.monthlyReviewTapped) }
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
            DashboardHeroSection(
                streakDays: store.currentStreakDays,
                sessionsCompleted: store.sessionsCompleted,
                totalFocusMinutes: store.totalFocusMinutes
            )
            .padding(.horizontal, 24)

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 20),
                    GridItem(.flexible(), spacing: 20)
                ],
                alignment: .center,
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
