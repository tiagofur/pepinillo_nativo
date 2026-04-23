// DashboardView.swift
// Pepinillo — Deep Work Companion for Apple
//
// Dashboard tab — the reflection engine.
// Same 1-column layout on iPhone, iPad portrait, and iPad landscape.
// Composes shared components from Analytics/Components/:
//   • DashboardHeroSection       — streak + sessions + focus time
//   • DashboardReflectionActions — Weekly/Monthly Review entry points
//   • DashboardStatCards         — period summary stat row
//   • DashboardChartsContent     — bar chart + patterns + breakdown + streaks
//
// Toolbar exposes Weekly Review, Monthly Review, and AI Report (if enabled)
// across all platforms.

import SwiftUI
import ComposableArchitecture

struct DashboardView: View {
    @Bindable var store: StoreOf<AnalyticsFeature>
    @Environment(\.appTheme) private var theme

    var body: some View {
        ZStack {
            ScrollView {
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
                Button {
                    store.send(.monthlyReviewTapped)
                } label: {
                    Label(String(localized: "Monthly Review"), systemImage: "calendar.badge.checkmark")
                }
            }
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
