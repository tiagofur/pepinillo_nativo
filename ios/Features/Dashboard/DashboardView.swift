// DashboardView.swift
// Pepinillo — Deep Work Companion for Apple
//
// Dashboard tab — the reflection engine.
// Layout (top to bottom):
//   1. Streak hero card   — flame + streak number + protection badge (emotional anchor)
//   2. 7-day focus chart  — bar chart for the last 7 days (today rightmost)
//   3. Compact stats row  — total time + sessions count (once, no duplication)
//   4. Review cards       — weekly / monthly with live data preview line
//   5. Full analytics section (period picker + DashboardChartsContent)
//
// The duplicated stats grid that previously appeared alongside DashboardHeroSection
// has been removed; numbers are now shown exactly once.

import SwiftUI
import Charts
import ComposableArchitecture

struct DashboardView: View {
    @Bindable var store: StoreOf<AnalyticsFeature>
    @Environment(\.appTheme) private var theme
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                // 1. Streak — emotional hero
                StreakHeroCard(
                    streakDays: store.currentStreakDays,
                    streakProtectionApplied: store.streakProtectionApplied,
                    theme: theme
                )

                if store.isLoading {
                    AnalyticsPlaceholder()
                        .redacted(reason: .placeholder)
                } else if let loadError = store.loadError {
                    ContentUnavailableView {
                        Label(String(localized: "Couldn't Load Data"), systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(loadError)
                    } actions: {
                        Button(String(localized: "Retry")) { store.send(.retryTapped) }
                            .buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 48)
                    .pepinilloGlass(cornerRadius: GlassCornerRadius.card)
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
                    // 2. 7-day focus chart as the hero visual
                    FocusSparkChart(
                        chartData: weekChartData,
                        dominantColor: dominantColor,
                        theme: theme
                    )

                    // 3. Compact stats row — always 7-day totals to match the chart above.
                    DashboardCompactStats(
                        formattedTotalTime: weekFormattedTotalTime,
                        sessionsCompleted: weekSessionsCompleted,
                        theme: theme
                    )

                    // 4. Review entry points with live preview lines
                    DashboardReflectionActions(
                        onWeeklyReview:  { store.send(.weeklyReviewTapped) },
                        onMonthlyReview: { store.send(.monthlyReviewTapped) },
                        weeklyPreview: weeklyPreviewLine,
                        monthlyPreview: monthlyPreviewLine
                    )

                    // 5. Full analytics section (period picker + charts)
                    analyticsSectionHeader

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
        .refreshable { store.send(.refresh) }
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

    // MARK: - Helpers

    /// Always the last 7 days of data, regardless of which period the picker shows.
    private var weekChartData: [AnalyticsFeature.State.DayPoint] {
        if store.period == .week {
            return store.chartData
        }
        // When a different period is selected, slice the last 7 points.
        let all = store.chartData
        guard all.count >= 7 else { return all }
        return Array(all.suffix(7))
    }

    private var dominantColor: Color {
        theme.color(for: store.dominantMode ?? .pomodoro)
    }

    private var formattedTotalTime: String {
        let hours = store.totalFocusMinutes / 60
        let minutes = store.totalFocusMinutes % 60
        if hours > 0 {
            return String(localized: "\(hours)h \(minutes)m")
        }
        return String(localized: "\(minutes)m")
    }

    /// Total focus minutes for the last 7 days (matches the 7-day spark chart, always).
    private var weekTotalMinutes: Int {
        weekChartData.reduce(0) { $0 + $1.totalMinutes }
    }

    /// Formatted focus time for the last 7 days — used by the compact stats row.
    private var weekFormattedTotalTime: String {
        formatMinutes(weekTotalMinutes)
    }

    /// Session count for the last 7 days — used by the compact stats row.
    private var weekSessionsCompleted: Int {
        weekChartData.reduce(0) { $0 + $1.sessionsCompleted }
    }

    /// Live preview line for the Weekly Review row.
    private var weeklyPreviewLine: String? {
        guard store.hasLoadedData else { return nil }
        let points = weekChartData
        let totalMinutes = points.reduce(0) { $0 + $1.totalMinutes }
        let totalSessions = points.reduce(0) { $0 + $1.sessionsCompleted }
        guard totalMinutes > 0 || totalSessions > 0 else { return nil }
        let timeStr = formatMinutes(totalMinutes)
        return String(
            format: NSLocalizedString(
                "dashboard.reflection.weekly.preview",
                value: "%@ focused in %d sessions this week",
                comment: "Weekly Review card live preview. %@ = formatted time (e.g. 3h 20m), %d = session count."
            ),
            timeStr, totalSessions
        )
    }

    /// Live preview line for the Monthly Review row.
    /// Only shown when the period picker is on 30D so the totals are month-scale.
    private var monthlyPreviewLine: String? {
        guard store.hasLoadedData, store.period == .month else { return nil }
        guard store.totalFocusMinutes > 0 || store.sessionsCompleted > 0 else { return nil }
        let timeStr = formatMinutes(store.totalFocusMinutes)
        return String(
            format: NSLocalizedString(
                "dashboard.reflection.monthly.preview",
                value: "%@ focused in %d sessions this month",
                comment: "Monthly Review card live preview. %@ = formatted time (e.g. 18h 25m), %d = session count."
            ),
            timeStr, store.sessionsCompleted
        )
    }

    private func formatMinutes(_ minutes: Int) -> String {
        let h = minutes / 60
        let m = minutes % 60
        if h > 0 { return m > 0 ? "\(h)h \(m)m" : "\(h)h" }
        return "\(m)m"
    }
}

// MARK: - Streak Hero Card

/// Large streak card — the emotional anchor at the top of the dashboard.
private struct StreakHeroCard: View {
    let streakDays: Int
    let streakProtectionApplied: Bool
    let theme: AppTheme

    var body: some View {
        HStack(spacing: 20) {
            // Flame icon + optional shield badge
            ZStack(alignment: .bottomTrailing) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 42, weight: .semibold))
                    .foregroundStyle(theme.streakColor)
                    .frame(width: 64, height: 64)
                    .background(theme.streakColor.opacity(0.12), in: Circle())
                    .accessibilityHidden(true)

                if streakProtectionApplied {
                    Image(systemName: "shield.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 24, height: 24)
                        .background(theme.streakColor, in: Circle())
                        .offset(x: 3, y: 3)
                        .accessibilityHidden(true)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("\(streakDays)")
                        .font(NumericFont.heroStat())
                        .foregroundStyle(.primary)
                        .contentTransition(.numericText())
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                    Text(String(localized: "day streak"))
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.primary)
                }

                if streakProtectionApplied {
                    Text(String(localized: "streak.protection.caption",
                                defaultValue: "Streak protected · Pro skip used"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .accessibilityLabel(String(localized: "streak.protection.accessibility",
                                                   defaultValue: "Streak protected by Pro skip"))
                } else {
                    Text(streakDays > 0
                         ? String(localized: "Keep the chain alive today.")
                         : String(localized: "Start one focused session today."))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .pepinilloGlass(cornerRadius: GlassCornerRadius.hero)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            streakProtectionApplied
                ? "\(streakDays) day streak, protected by Pro"
                : "\(streakDays) day streak"
        )
    }
}

// MARK: - Compact Stats Row

/// Single row showing focus time + sessions — appears once below the chart.
private struct DashboardCompactStats: View {
    let formattedTotalTime: String
    let sessionsCompleted: Int
    let theme: AppTheme

    var body: some View {
        HStack(spacing: 12) {
            compactStat(
                icon: "clock.fill",
                value: formattedTotalTime,
                label: String(localized: "focused"),
                color: .teal
            )

            Divider()
                .frame(height: 32)

            compactStat(
                icon: "checkmark.circle.fill",
                value: "\(sessionsCompleted)",
                label: String(localized: "sessions"),
                color: theme.flowtimeColor
            )

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .pepinilloGlass(cornerRadius: GlassCornerRadius.card)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(formattedTotalTime) focused, \(sessionsCompleted) sessions")
    }

    private func compactStat(icon: String, value: String, label: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(color)
                .accessibilityHidden(true)
            Text(value)
                .font(NumericFont.kpi())
                .foregroundStyle(.primary)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - 7-Day Focus Spark Chart

/// Hero bar chart for the last 7 days. Bars grow in on appear (Reduce Motion aware).
struct FocusSparkChart: View {
    let chartData: [AnalyticsFeature.State.DayPoint]
    let dominantColor: Color
    let theme: AppTheme

    @State private var appeared = false
    @State private var selectedDate: Date?

    private var averageMinutes: Double {
        guard !chartData.isEmpty else { return 0 }
        let total = chartData.reduce(0) { $0 + $1.totalMinutes }
        return Double(total) / Double(chartData.count)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(String(localized: "Focus this week"))
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                if let avg = averageAnnotation {
                    Text(avg)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Chart {
                // Average rule mark
                if averageMinutes > 0 {
                    RuleMark(y: .value(String(localized: "Average"), averageMinutes))
                        .foregroundStyle(dominantColor.opacity(0.35))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        .annotation(position: .trailing, spacing: 4) {
                            Text(String(localized: "avg"))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .accessibilityHidden(true)
                }

                ForEach(chartData) { point in
                    let isToday = Calendar.current.isDateInToday(point.date)
                    let isSelected = selectedDate.map {
                        Calendar.current.isDate($0, inSameDayAs: point.date)
                    } == true

                    BarMark(
                        x: .value(
                            String(localized: "Day"),
                            point.date,
                            unit: .day
                        ),
                        y: .value(
                            String(localized: "Minutes"),
                            appeared ? max(point.totalMinutes, point.totalMinutes == 0 ? 1 : 0) : 0
                        )
                    )
                    .foregroundStyle(
                        isToday
                            ? dominantColor
                            : isSelected
                                ? dominantColor.opacity(0.85)
                                : selectedDate != nil
                                    ? dominantColor.opacity(0.25)
                                    : dominantColor.opacity(0.6)
                    )
                    .cornerRadius(5)
                    .accessibilityLabel(
                        point.totalMinutes > 0
                        ? "\(point.date.formatted(.dateTime.weekday(.wide))), \(point.totalMinutes) minutes"
                        : "\(point.date.formatted(.dateTime.weekday(.wide))), no focus"
                    )
                    .accessibilityValue(
                        point.totalMinutes > 0
                        ? String(localized: "\(point.totalMinutes) minutes")
                        : String(localized: "No data")
                    )
                }

                // Selected annotation
                if let selected = selectedDate,
                   let point = chartData.first(where: { Calendar.current.isDate($0.date, inSameDayAs: selected) }) {
                    RuleMark(x: .value(String(localized: "Selected"), point.date, unit: .day))
                        .foregroundStyle(dominantColor.opacity(0.25))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4]))
                        .annotation(position: .top, spacing: 4) {
                            VStack(spacing: 2) {
                                Text(point.date.formatted(.dateTime.weekday(.abbreviated)))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Text(point.totalMinutes > 0
                                     ? String(localized: "\(point.totalMinutes) min")
                                     : String(localized: "No focus"))
                                    .font(.caption.weight(.semibold))
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 7))
                        }
                }
            }
            .chartXSelection(value: $selectedDate)
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { value in
                    AxisValueLabel {
                        if let date = value.as(Date.self) {
                            let isToday = Calendar.current.isDateInToday(date)
                            Text(date.formatted(.dateTime.weekday(.narrow)))
                                .font(.caption2)
                                .fontWeight(isToday ? .bold : .regular)
                                .foregroundStyle(isToday ? dominantColor : .secondary)
                        }
                    }
                }
            }
            .chartYAxis(.hidden)
            .frame(height: 140)
            .accessibilityLabel(String(localized: "dashboard.chart.weeklyBars.label",
                                       defaultValue: "Bar chart showing focus minutes for each day of the last 7 days"))
        }
        .padding(16)
        .pepinilloGlass(cornerRadius: GlassCornerRadius.card)
        .onAppear {
            appeared = true
        }
        .conditionalAnimation(
            .spring(response: 0.7, dampingFraction: 0.75).delay(0.05),
            value: appeared
        )
    }

    private var averageAnnotation: String? {
        guard averageMinutes >= 1 else { return nil }
        let mins = Int(averageMinutes.rounded())
        let h = mins / 60
        let m = mins % 60
        if h > 0 {
            return String(localized: "~\(h)h\(m)m avg")
        }
        return String(localized: "~\(mins)m avg")
    }
}
