// AnalyticsView.swift
// Pepinillo — Deep Work Companion for Apple
//
// Analytics dashboard: period picker, summary cards, bar chart, and mode breakdown.
// Uses SwiftCharts (iOS 16+) for visualizations.

import SwiftUI
import Charts
import ComposableArchitecture

struct AnalyticsView: View {
    @Bindable var store: StoreOf<AnalyticsFeature>
    @Environment(\.appTheme) private var theme

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
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
                        summaryCards
                            .padding(.horizontal, 16)

                        focusBarChart
                            .padding(.horizontal, 16)

                        productivityPatternsSection
                            .padding(.horizontal, 16)

                        if !store.modeBreakdown.isEmpty {
                            modeBreakdownSection
                                .padding(.horizontal, 16)
                        }

                        if !store.achievements.isEmpty {
                            AchievementsSection(achievements: store.achievements)
                                .padding(.horizontal, 16)
                        }

                        streakSection
                            .padding(.horizontal, 16)
                    }
                }
                .padding(.bottom, 32)
            }
            .refreshable { store.send(.onAppear) }
            .navigationTitle(String(localized: "Analytics"))
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
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
            .sheet(item: $store.scope(state: \.weeklyReview, action: \.weeklyReview)) { weeklyStore in
                WeeklyReviewView(store: weeklyStore)
            }
            .sheet(item: $store.scope(state: \.monthlyReview, action: \.monthlyReview)) { monthlyStore in
                MonthlyReviewView(store: monthlyStore)
            }
            .sheet(item: $store.scope(state: \.aiReport, action: \.aiReport)) { aiReportStore in
                AIReportView(store: aiReportStore)
            }
            .onAppear { store.send(.onAppear) }
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

    // MARK: - Summary Cards

    private var summaryCards: some View {
        HStack(spacing: 12) {
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
    }

    // MARK: - Focus Bar Chart

    @State private var selectedChartDate: Date?
    @State private var chartAppeared = false

    private var focusBarChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "Focus Minutes"))
                .font(.headline)
                .accessibilityAddTraits(.isHeader)

            Chart {
                ForEach(store.chartData) { point in
                    BarMark(
                        x: .value("Date", point.date, unit: .day),
                        y: .value("Minutes", point.totalMinutes)
                    )
                    .foregroundStyle(
                        selectedChartDate.map { Calendar.current.isDate($0, inSameDayAs: point.date) } == true
                            ? dominantColor
                            : selectedChartDate != nil
                                ? dominantColor.opacity(0.3)
                                : dominantColor
                    )
                    .cornerRadius(4)
                    .accessibilityLabel("\(point.date, format: .dateTime.weekday(.abbreviated).month(.abbreviated).day()), \(point.totalMinutes) minutes")
                }

                if let selected = selectedChartDate,
                   let point = store.chartData.first(where: { Calendar.current.isDate($0.date, inSameDayAs: selected) }) {
                    RuleMark(x: .value("Selected", point.date, unit: .day))
                        .foregroundStyle(dominantColor.opacity(0.3))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        .annotation(position: .top, spacing: 4) {
                            VStack(spacing: 2) {
                                Text(point.date, format: .dateTime.weekday(.abbreviated).month(.abbreviated).day())
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Text(String(localized: "\(point.totalMinutes) min"))
                                    .font(.caption)
                                    .fontWeight(.semibold)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6))
                        }
                }
            }
            .chartXSelection(value: $selectedChartDate)
            .chartXAxis {
                switch store.period {
                case .week:
                    AxisMarks(values: .stride(by: .day)) { _ in
                        AxisValueLabel(format: .dateTime.weekday(.abbreviated))
                    }
                case .month:
                    AxisMarks(values: .automatic(desiredCount: 6)) { _ in
                        AxisValueLabel(format: .dateTime.day())
                    }
                case .year:
                    AxisMarks(values: .automatic(desiredCount: 6)) { _ in
                        AxisValueLabel(format: .dateTime.month(.abbreviated))
                    }
                }
            }
            .chartYAxis {
                AxisMarks { value in
                    AxisValueLabel()
                    AxisGridLine()
                }
            }
            .frame(height: chartHeight)
            .padding(.top, 4)
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .opacity(chartAppeared ? 1 : 0)
        .conditionalAnimation(.easeIn(duration: 0.5), value: chartAppeared)
        .onAppear { chartAppeared = true }
    }

    // MARK: - Productivity Patterns

    private var productivityPatternsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "Productivity Patterns"))
                .font(.headline)
                .accessibilityAddTraits(.isHeader)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                PatternCard(
                    title: String(localized: "Peak Hours"),
                    value: store.peakHourRange.isEmpty ? "–" : store.peakHourRange,
                    icon: "clock.fill",
                    color: .orange
                )
                PatternCard(
                    title: String(localized: "Best Day"),
                    value: store.bestDayOfWeek.isEmpty ? "–" : store.bestDayOfWeek,
                    icon: "calendar",
                    color: .purple
                )
                PatternCard(
                    title: String(localized: "Completion"),
                    value: "\(Int(store.sessionCompletionRate * 100))%",
                    icon: "checkmark.circle.fill",
                    color: .green
                )
                PatternCard(
                    title: String(localized: "Focus Score"),
                    value: "\(store.focusQualityScore)",
                    icon: "brain.head.profile",
                    color: theme.pomodoroColor
                )
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Mode Breakdown

    private var modeBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "Mode Breakdown"))
                .font(.headline)
                .accessibilityAddTraits(.isHeader)

            VStack(spacing: 8) {
                ForEach(store.modeBreakdown) { share in
                    ModeShareRow(share: share, theme: theme)
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Streak Section

    private var streakSection: some View {
        HStack(spacing: 16) {
            StreakCard(
                title: String(localized: "Current"),
                days: store.currentStreakDays,
                icon: "flame.fill",
                color: theme.streakColor
            )
            StreakCard(
                title: String(localized: "Best"),
                days: store.longestStreakDays,
                icon: "trophy.fill",
                color: .yellow
            )
        }
    }

    // MARK: - Helpers

    private var dominantColor: Color {
        theme.color(for: store.dominantMode ?? .pomodoro)
    }

    private var chartHeight: CGFloat {
        store.period == .year ? 140 : 180
    }

    private var formattedTotalTime: String {
        let hours = store.totalFocusMinutes / 60
        let minutes = store.totalFocusMinutes % 60
        if hours > 0 {
            return String(localized: "\(hours)h \(minutes)m")
        }
        return String(localized: "\(minutes)m")
    }
}

// MARK: - Summary Card

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

// MARK: - Mode Share Row

struct ModeShareRow: View {
    let share: AnalyticsFeature.State.ModeShare
    let theme: AppTheme

    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Text(share.mode.icon)
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

// MARK: - Pattern Card

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

// MARK: - Streak Card

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

private struct AnalyticsPlaceholder: View {
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
