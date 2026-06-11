// DashboardView.swift
// Pepinillo — Deep Work Companion for Apple
//
// Dashboard tab — the reflection engine.
// Layout: VStack of full-width sections (Hero, ReflectionActions, analytics header, ChartsContent).
// Only the 3 KPI SummaryCards live in an inner LazyVGrid that reflows:
//   1 col iPhone / 2 cols iPad portrait / 3 cols iPad landscape.
// .gridCellColumns does NOT work reliably with adaptive LazyVGrid — items end up packed
// in column 1. Use VStack for full-width items and nested LazyVGrid only for tiles.
//
// Toolbar exposes Weekly Review, Monthly Review, and AI Report (if enabled)
// across all platforms.

import SwiftUI
import ComposableArchitecture

struct DashboardView: View {
    @Bindable var store: StoreOf<AnalyticsFeature>
    @Environment(\.appTheme) private var theme
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(spacing: 14) {
                    // Hero — always full width
                    DashboardHeroSection(
                        streakDays: store.currentStreakDays,
                        sessionsCompleted: store.sessionsCompleted,
                        totalFocusMinutes: store.totalFocusMinutes,
                        streakProtectionApplied: store.streakProtectionApplied
                    )

                    // Reflection CTAs — always full width
                    DashboardReflectionActions(
                        onWeeklyReview:  { store.send(.weeklyReviewTapped) },
                        onMonthlyReview: { store.send(.monthlyReviewTapped) }
                    )
                }

                if store.isLoading {
                    AnalyticsPlaceholder()
                        .redacted(reason: .placeholder)
                } else if store.chartData.isEmpty && store.sessionsCompleted == 0 {
                    ContentUnavailableView(
                        String(localized: "No Data Yet"),
                        systemImage: "chart.bar",
                        description: Text(String(localized: "Complete your first focus session to see your analytics here."))
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 48)
                    .pepinilloGlass(cornerRadius: GlassCornerRadius.card)
                } else {
                    // Analytics period header — full width
                    analyticsSectionHeader

                    // KPI stat tiles: 1 col iPhone / 2 cols iPad portrait / 3 cols iPad landscape
                    LazyVGrid(columns: dashboardMetricColumns, spacing: 12) {
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
                        }

                    // Charts — always full width
                    DashboardChartsContent(store: store)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 32)
            .contentMaxWidth()
        }
        .primaryScrollEdgeEffect()
        .background(Color.pepinilloSystemGroupedBackground)
        .scrollContentBackground(.hidden)
        .refreshable { store.send(.onAppear) }
        .navigationTitle(String(localized: "Dashboard"))
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                // Reviews menu — Weekly + Monthly in one icon, with optional AI submenu.
                Menu {
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
                    if AppConfig.aiInsightsEnabled {
                        Divider()
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
                    }
                } label: {
                    Label(String(localized: "Reviews"), systemImage: "calendar")
                        .accessibilityLabel(String(localized: "dashboard.toolbar.reviews.label",
                                                   defaultValue: "Open weekly or monthly review"))
                }
            }
        }
        .onAppear { store.send(.onAppear) }
    }

    // MARK: - Analytics Section Header

    private var analyticsSectionHeader: some View {
        HStack {
            Text(String(localized: "Analytics"))
                .font(.title3.weight(.semibold))
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
        .frame(width: sizeClass == .regular ? 220 : 180)
    }

    private var dashboardMetricColumns: [GridItem] {
        [GridItem(.adaptive(minimum: sizeClass == .regular ? 220 : 150), spacing: 12)]
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
