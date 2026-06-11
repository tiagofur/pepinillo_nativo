// DashboardWidgetViews.swift
// Pepinillo — Deep Work Companion for Apple
//
// Views for the Dashboard widget with SwiftUI Charts.
// Shows weekly focus progress with mode-colored stacked bars.

import SwiftUI
import Charts
import WidgetKit

// MARK: - Pro Lock Overlay

struct ProWidgetOverlay: View {
    let title: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "lock.fill")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text(title)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Text(String(localized: "Pepinillo+ required"))
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.pepinilloSystemBackground.opacity(0.8))
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

// MARK: - Small Widget

struct DashboardWidgetSmall: View {
    let entry: DashboardWidgetEntry
    @Environment(\.showsWidgetContainerBackground) var showsBackground

    var body: some View {
        Group {
            if showsBackground {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "chart.bar.fill")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(String(localized: "Dashboard"))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }

                    Spacer()

                    // Today's focus
                    Text(formattedMinutes(entry.todayMinutes))
                        .font(.system(.title, design: .rounded, weight: .bold))

                    // Trend indicator vs yesterday
                    HStack(spacing: 4) {
                        Text(String(localized: "today"))
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        if entry.todayMinutes > entry.yesterdayMinutes && entry.yesterdayMinutes > 0 {
                            Image(systemName: "arrow.up.right")
                                .font(.caption2)
                                .foregroundStyle(.green)
                        } else if entry.todayMinutes < entry.yesterdayMinutes {
                            Image(systemName: "arrow.down.right")
                                .font(.caption2)
                                .foregroundStyle(.orange)
                        }
                    }

                    // Streak
                    if entry.streakDays > 0 {
                        HStack(spacing: 3) {
                            Image(systemName: "flame.fill")
                                .font(.caption2)
                                .foregroundStyle(ModeColors.streak)
                            Text("\(entry.streakDays)d")
                                .font(.caption2)
                                .fontWeight(.medium)
                        }
                    }
                }
                .padding(0)
            } else {
                // StandBy mode
                VStack(spacing: 8) {
                    Text(formattedMinutes(entry.todayMinutes))
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                    if entry.streakDays > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "flame.fill")
                                .foregroundStyle(ModeColors.streak)
                            Text("\(entry.streakDays)d")
                                .fontWeight(.semibold)
                        }
                        .font(.title3)
                    }
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Medium Widget

struct DashboardWidgetMedium: View {
    let entry: DashboardWidgetEntry
    @Environment(\.showsWidgetContainerBackground) var showsBackground

    var body: some View {
        Group {
            if showsBackground {
                HStack(spacing: 14) {
                    // Left: today's stats
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 4) {
                            Image(systemName: "chart.bar.fill")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(String(localized: "Dashboard"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Text(formattedMinutes(entry.todayMinutes))
                            .font(.system(.title2, design: .rounded, weight: .bold))
                        Text(String(localized: "today"))
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        HStack(spacing: 12) {
                            StatPill(icon: "checkmark.circle", value: "\(entry.todaySessions)")
                            if entry.streakDays > 0 {
                                StatPill(icon: "flame.fill", value: "\(entry.streakDays)d", color: ModeColors.streak)
                            }
                        }
                    }

                    Divider()

                    // Right: weekly chart
                    VStack(alignment: .leading, spacing: 4) {
                        Text(String(localized: "This week"))
                            .font(.caption2)
                            .foregroundStyle(.secondary)

                        if entry.weeklyData.isEmpty {
                            Spacer()
                            Text(String(localized: "No data yet"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                        } else {
                            WeeklyBarChart(data: entry.weeklyData, height: 60)
                            Text(String(localized: "\(formattedMinutes(entry.weeklyTotalMinutes)) total"))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(0)
            } else {
                // StandBy
                HStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(formattedMinutes(entry.todayMinutes))
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)
                        Text(String(localized: "today"))
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                    if entry.streakDays > 0 {
                        VStack(spacing: 4) {
                            Image(systemName: "flame.fill")
                                .font(.title2)
                                .foregroundStyle(ModeColors.streak)
                            Text("\(entry.streakDays)d")
                                .font(.title3)
                                .fontWeight(.semibold)
                        }
                    }
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Large Widget

struct DashboardWidgetLarge: View {
    let entry: DashboardWidgetEntry
    @Environment(\.showsWidgetContainerBackground) var showsBackground

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
                // Header
                HStack {
                    Image(systemName: "chart.bar.fill")
                        .foregroundStyle(.secondary)
                    Text(String(localized: "Dashboard"))
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                    if entry.streakDays > 0 {
                        HStack(spacing: 3) {
                            Image(systemName: "flame.fill")
                                .foregroundStyle(ModeColors.streak)
                            Text("\(entry.streakDays)d")
                                .fontWeight(.semibold)
                        }
                        .font(.subheadline)
                    }
                }

                // Today stats row
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(formattedMinutes(entry.todayMinutes))
                            .font(.system(.title, design: .rounded, weight: .bold))
                        Text(String(localized: "today"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(entry.todaySessions)")
                            .font(.system(.title3, design: .rounded, weight: .bold))
                        Text(String(localized: "sessions"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(formattedMinutes(entry.weeklyTotalMinutes))
                            .font(.system(.title3, design: .rounded, weight: .bold))
                        Text(String(localized: "this week"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Divider()

                // Weekly chart
                if !entry.weeklyData.isEmpty {
                    Text(String(localized: "Weekly Overview"))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    WeeklyBarChart(data: entry.weeklyData, height: 100)

                    // Mode legend
                    HStack(spacing: 12) {
                        ModeLegendItem(color: ModeColors.pomodoro, label: String(localized: "Pomodoro"))
                        ModeLegendItem(color: ModeColors.flowtime, label: String(localized: "Flow"))
                        ModeLegendItem(color: ModeColors.timeBlock, label: String(localized: "Blocks"))
                        ModeLegendItem(color: ModeColors.stopwatch, label: String(localized: "Chrono"))
                    }

                    // Best day callout
                    if entry.bestDayMinutes > 0 {
                        HStack(spacing: 6) {
                            Image(systemName: "star.fill")
                                .font(.caption2)
                                .foregroundStyle(.yellow)
                            Text(String(localized: "Best: \(entry.bestDayName) — \(formattedMinutes(entry.bestDayMinutes))"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                } else {
                    Spacer()
                    HStack {
                        Spacer()
                        VStack(spacing: 8) {
                            Image(systemName: "chart.bar")
                                .font(.largeTitle)
                                .foregroundStyle(.secondary)
                            Text(String(localized: "Start focusing to see your stats"))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    Spacer()
                }
        }
        .padding(0)
    }
}

// MARK: - Weekly Bar Chart (SwiftUI Charts)

private struct WeeklyBarChart: View {
    let data: [DashboardWidgetEntry.DayData]
    let height: CGFloat

    var body: some View {
        Chart(data) { day in
            // Stacked bars by mode
            if day.pomodoroMinutes > 0 {
                BarMark(
                    x: .value("Day", day.dayAbbrev),
                    y: .value("Minutes", day.pomodoroMinutes)
                )
                .foregroundStyle(ModeColors.pomodoro)
            }
            if day.flowtimeMinutes > 0 {
                BarMark(
                    x: .value("Day", day.dayAbbrev),
                    y: .value("Minutes", day.flowtimeMinutes)
                )
                .foregroundStyle(ModeColors.flowtime)
            }
            if day.timeBlockMinutes > 0 {
                BarMark(
                    x: .value("Day", day.dayAbbrev),
                    y: .value("Minutes", day.timeBlockMinutes)
                )
                .foregroundStyle(ModeColors.timeBlock)
            }
            if day.stopwatchMinutes > 0 {
                BarMark(
                    x: .value("Day", day.dayAbbrev),
                    y: .value("Minutes", day.stopwatchMinutes)
                )
                .foregroundStyle(ModeColors.stopwatch)
            }
        }
        .chartYAxis(.hidden)
        .chartXAxis {
            AxisMarks { value in
                AxisValueLabel {
                    if let abbrev = value.as(String.self) {
                        let matchingDay = data.first { $0.dayAbbrev == abbrev }
                        Text(abbrev)
                            .font(.caption2)
                            .fontWeight(matchingDay?.isToday == true ? .bold : .regular)
                            .foregroundStyle(matchingDay?.isToday == true ? .primary : .secondary)
                    }
                }
            }
        }
        .chartLegend(.hidden)
        .frame(height: height)
    }
}

// MARK: - Supporting Views

private struct StatPill: View {
    let icon: String
    let value: String
    var color: Color = .accentColor

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundStyle(color)
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
        }
    }
}

private struct ModeLegendItem: View {
    let color: Color
    let label: String

    var body: some View {
        HStack(spacing: 3) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Helpers

private func formattedMinutes(_ minutes: Int) -> String {
    if minutes >= 60 {
        let h = minutes / 60
        let m = minutes % 60
        return m > 0 ? "\(h)h \(m)m" : "\(h)h"
    }
    return "\(minutes)m"
}
