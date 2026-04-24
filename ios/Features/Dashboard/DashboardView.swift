// DashboardView.swift
// Pepinillo — Deep Work Companion for Apple
//
// Dashboard tab — the reflection engine.
// Adaptive LazyVGrid: 1 col iPhone, 2 cols iPad portrait, 3 cols iPad landscape/13".
// Composes shared components from Analytics/Components/:
//   • DashboardHeroSection       — streak + sessions + focus time  (spans 2 cols)
//   • DashboardReflectionActions — Weekly/Monthly Review entry points  (spans 2 cols)
//   • SummaryCard                — KPI tiles (1 col each, tile naturally)
//   • DashboardChartsContent     — bar chart + patterns + breakdown + streaks  (spans 2 cols)
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
                LazyVGrid(columns: adaptiveCardColumns, spacing: 16) {
                    // Hero — full width on iPad (spans both cols)
                    // HeroStatCard sub-components carry their own .pepinilloGlass chrome.
                    DashboardHeroSection(
                        streakDays: store.currentStreakDays,
                        sessionsCompleted: store.sessionsCompleted,
                        totalFocusMinutes: store.totalFocusMinutes
                    )
                    .gridCellColumns(2)

                    // Reflection CTAs — full width on iPad
                    // ReflectionCard sub-components carry their own .pepinilloGlass chrome.
                    DashboardReflectionActions(
                        onWeeklyReview:  { store.send(.weeklyReviewTapped) },
                        onMonthlyReview: { store.send(.monthlyReviewTapped) }
                    )
                    .gridCellColumns(2)

                    if store.isLoading {
                        AnalyticsPlaceholder()
                            .redacted(reason: .placeholder)
                            .gridCellColumns(2)
                    } else if store.chartData.isEmpty && store.sessionsCompleted == 0 {
                        ContentUnavailableView(
                            String(localized: "No Data Yet"),
                            systemImage: "chart.bar",
                            description: Text(String(localized: "Complete your first focus session to see your analytics here."))
                        )
                        .padding(.top, 40)
                        .gridCellColumns(2)
                    } else {
                        // Analytics period header — full width
                        analyticsSectionHeader
                            .padding(.horizontal, 16)
                            .gridCellColumns(2)

                        // KPI stat cards — tile individually (1 col each)
                        SummaryCard(
                            title: String(localized: "Focus Time"),
                            value: formattedTotalTime,
                            icon: "brain.head.profile",
                            color: theme.pomodoroColor
                        )
                        SummaryCard(
                            title: String(localized: "Sessions"),
                            value: "\(store.sessionsCompleted)",
                            icon: "checkmark.circle",
                            color: theme.flowtimeColor
                        )
                        SummaryCard(
                            title: String(localized: "Streak"),
                            value: "\(store.currentStreakDays)d",
                            icon: "flame.fill",
                            color: theme.streakColor
                        )

                        // Charts — full width on iPad
                        DashboardChartsContent(store: store)
                            .gridCellColumns(2)
                    }
                }
                .padding(16)
                .contentMaxWidth()
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
