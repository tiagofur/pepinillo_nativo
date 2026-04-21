// DashboardView.swift
// Pepinillo — Deep Work Companion for Apple
//
// Dashboard tab — the reflection engine (iPhone / compact size class).
// Composes shared components from Analytics/Components/:
//   • DashboardHeroSection   — streak + sessions + focus time
//   • DashboardReflectionActions — Weekly/Monthly Review entry points
//   • DashboardStatCards     — period summary stat row
//   • DashboardChartsContent — bar chart + patterns + breakdown + streaks
//
// On compact (iPhone): single-column VStack.
// On regular (iPad/Mac): the caller (AnalyticsView) handles two-column layout.

import SwiftUI
import ComposableArchitecture

struct DashboardView: View {
    @Bindable var store: StoreOf<AnalyticsFeature>
    @Environment(\.appTheme) private var theme

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Hero: streak + today summary
                DashboardHeroSection(
                    streakDays: store.currentStreakDays,
                    sessionsCompleted: store.sessionsCompleted,
                    totalFocusMinutes: store.totalFocusMinutes
                )
                .padding(.horizontal, 16)

                // Quick actions: Reviews
                DashboardReflectionActions(
                    onWeeklyReview:  { store.send(.weeklyReviewTapped) },
                    onMonthlyReview: { store.send(.monthlyReviewTapped) }
                )
                .padding(.horizontal, 16)

                // Analytics section
                if !store.isLoading && (!store.chartData.isEmpty || store.sessionsCompleted > 0) {
                    analyticsSectionHeader
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
            .padding(.bottom, 32)
        }
        .refreshable { store.send(.onAppear) }
        .navigationTitle(String(localized: "Dashboard"))
        .sheet(item: $store.scope(state: \.weeklyReview, action: \.weeklyReview)) { weeklyStore in
            WeeklyReviewView(store: weeklyStore, isProUser: store.isProUser, analyticsStore: store)
        }
        .sheet(item: $store.scope(state: \.monthlyReview, action: \.monthlyReview)) { monthlyStore in
            MonthlyReviewView(store: monthlyStore, isProUser: store.isProUser, analyticsStore: store)
        }
        .onAppear { store.send(.onAppear) }
    }

    // MARK: - Analytics Section Header

    private var analyticsSectionHeader: some View {
        HStack {
            Text(String(localized: "Analytics"))
                .font(.headline)
            Spacer()
            periodPicker
        }
    }

    private var periodPicker: some View {
        Picker(String(localized: "Period"), selection: Binding(
            get: { store.period },
            set: { store.send(.periodChanged($0)) }
        )) {
            ForEach(AnalyticsFeature.State.Period.allCases, id: \.self) { period in
                Text(period.displayName).tag(period)
            }
        }
        .pickerStyle(.segmented)
        .frame(width: 200)
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
