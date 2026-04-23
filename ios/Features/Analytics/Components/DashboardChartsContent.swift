// DashboardChartsContent.swift
// Pepinillo — Deep Work Companion for Apple
//
// Shared analytics charts block: period picker, focus bar chart,
// productivity patterns grid, mode breakdown, streak cards.
// Platform-agnostic — same component on iPhone, iPad, Mac Catalyst.
// The caller controls horizontal layout (compact vs. regular).

import SwiftUI
import Charts
import ComposableArchitecture

struct DashboardChartsContent: View {
    let store: StoreOf<AnalyticsFeature>

    @Environment(\.appTheme) private var theme
    @State private var selectedChartDate: Date?
    @State private var chartAppeared = false

    var body: some View {
        VStack(spacing: 16) {
            if !store.chartData.isEmpty {
                focusBarChart
            }

            productivityPatternsSection

            if !store.modeBreakdown.isEmpty {
                modeBreakdownSection
            }

            if !store.achievements.isEmpty {
                AchievementsSection(achievements: store.achievements)
            }

            streakSection
        }
        .onAppear { chartAppeared = true }
    }

    // MARK: - Focus Bar Chart

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
                    .accessibilityLabel(
                        "\(point.date, format: .dateTime.weekday(.abbreviated).month(.abbreviated).day()), \(point.totalMinutes) minutes"
                    )
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
                AxisMarks { _ in
                    AxisValueLabel()
                    AxisGridLine()
                }
            }
            .frame(height: chartHeight)
            .padding(.top, 4)
            .accessibilityLabel(
                String(localized: "dashboard.charts.barChart.label", defaultValue: "Focus minutes bar chart for the selected period")
            )
        }
        .padding(16)
        .pepinilloGlass(cornerRadius: 16)
        .opacity(chartAppeared ? 1 : 0)
        .conditionalAnimation(.easeIn(duration: 0.5), value: chartAppeared)
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
        .pepinilloGlass(cornerRadius: 16)
        .accessibilityLabel(
            String(localized: "dashboard.charts.patterns.label", defaultValue: "Productivity patterns including peak hours, best day, completion rate, and focus score")
        )
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
        .pepinilloGlass(cornerRadius: 16)
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
}

// MARK: - Preview

#if DEBUG
#Preview("Charts — Empty") {
    DashboardChartsContent(store: Store(initialState: AnalyticsFeature.State()) {
        AnalyticsFeature()
    })
    .padding()
}
#endif
