// WatchDashboardView.swift
// Pepinillo — Deep Work Companion for Apple
//
// Apple Watch dashboard screen. Shows today's focus summary:
// total time, sessions, tasks, streak, and per-mode breakdown.

import SwiftUI
import ComposableArchitecture

// MARK: - WatchDashboardView

struct WatchDashboardView: View {
    @Bindable var store: StoreOf<WatchDashboardFeature>
    /// Phone-synced theme (#533). Per-mode accents resolve from the theme so
    /// Forest/Ocean/Sunset on the phone propagate to the watch dashboard.
    @Environment(\.appTheme) private var appTheme

    private var pomodoroAccent: Color { appTheme.color(for: .pomodoro) }
    private var flowtimeAccent: Color { appTheme.color(for: .flowtime) }
    private var timeBlockAccent: Color { appTheme.color(for: .timeBlock) }
    private var stopwatchAccent: Color { appTheme.color(for: .stopwatch) }
    private var streakAccent: Color { appTheme.streakColor }

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                // Header with date
                headerView

                // Main stats cards
                mainStatsView

                // Task progress
                taskProgressView

                // Mode distribution
                if totalModeMinutes > 0 {
                    modeDistributionView
                }

                // Best session
                if store.longestSessionMinutes > 0 {
                    bestSessionView
                }
            }
            .padding(.horizontal, 4)
            .padding(.top, 4)
        }
        .onAppear { store.send(.onAppear) }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            Image(systemName: "chart.bar.fill")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Text(String(localized: "Today"))
                .font(.system(size: 13, weight: .semibold))
            Spacer()
            Text(dateString)
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 4)
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter
    }()

    private var dateString: String {
        Self.dateFormatter.string(from: Date())
    }

    // MARK: - Main Stats

    private var mainStatsView: some View {
        HStack(spacing: 6) {
            // Focus time
            DashboardStatCard(
                icon: "timer",
                value: formatMinutes(store.todayFocusMinutes),
                label: String(localized: "Focus"),
                color: .blue
            )

            // Sessions
            DashboardStatCard(
                icon: "flame.fill",
                value: "\(store.sessionsCompleted)",
                label: String(localized: "Sessions"),
                color: .orange
            )
        }
    }

    // MARK: - Task Progress

    private var taskProgressView: some View {
        HStack(spacing: 8) {
            // Tasks completion
            DashboardStatCard(
                icon: "checkmark.circle",
                value: "\(store.tasksCompleted)/\(store.tasksTotal)",
                label: String(localized: "Tasks"),
                color: .green
            )

            // Streak
            DashboardStatCard(
                icon: "bolt.fill",
                value: store.streakDays > 0 ? "\(store.streakDays)d" : "—",
                label: String(localized: "Streak"),
                color: streakAccent
            )
        }
    }

    // MARK: - Mode Distribution

    private var totalModeMinutes: Int {
        store.pomodoroMinutes + store.flowtimeMinutes + store.timeBlockMinutes + store.stopwatchMinutes
    }

    private var modeDistributionView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(String(localized: "Modes"))
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.leading, 4)

            // Stacked bar
            GeometryReader { geo in
                let total = max(CGFloat(totalModeMinutes), 1)
                HStack(spacing: 1) {
                    let modes: [(Int, Color)] = [
                        (store.pomodoroMinutes, pomodoroAccent),
                        (store.flowtimeMinutes, flowtimeAccent),
                        (store.timeBlockMinutes, timeBlockAccent),
                        (store.stopwatchMinutes, stopwatchAccent),
                    ]
                    ForEach(Array(modes.enumerated()), id: \.offset) { _, item in
                        if item.0 > 0 {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(item.1)
                                .frame(width: max(geo.size.width * CGFloat(item.0) / total, 4))
                        }
                    }
                }
            }
            .frame(height: 8)
            .clipShape(Capsule())
            .padding(.horizontal, 4)

            // Legend
            HStack(spacing: 6) {
                if store.pomodoroMinutes > 0 {
                    ModeLegendItem(systemImage: FocusMode.pomodoro.systemImage, minutes: store.pomodoroMinutes, color: pomodoroAccent)
                }
                if store.flowtimeMinutes > 0 {
                    ModeLegendItem(systemImage: FocusMode.flowtime.systemImage, minutes: store.flowtimeMinutes, color: flowtimeAccent)
                }
                if store.timeBlockMinutes > 0 {
                    ModeLegendItem(systemImage: FocusMode.timeBlock.systemImage, minutes: store.timeBlockMinutes, color: timeBlockAccent)
                }
                if store.stopwatchMinutes > 0 {
                    ModeLegendItem(systemImage: FocusMode.stopwatch.systemImage, minutes: store.stopwatchMinutes, color: stopwatchAccent)
                }
            }
            .padding(.horizontal, 4)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 4)
        .pepinilloGlass(cornerRadius: 10)
    }

    // MARK: - Best Session

    private var bestSessionView: some View {
        HStack(spacing: 6) {
            Image(systemName: "trophy.fill")
                .font(.system(size: 11))
                .foregroundStyle(.yellow)
            Text(String(localized: "Best session"))
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Spacer()
            Text(formatMinutes(store.longestSessionMinutes))
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .monospacedDigit()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .pepinilloGlass(cornerRadius: 10)
    }

    // MARK: - Helpers

    private func formatMinutes(_ minutes: Int) -> String {
        if minutes >= 60 {
            let h = minutes / 60
            let m = minutes % 60
            return m > 0 ? "\(h)h\(m)m" : "\(h)h"
        }
        return "\(minutes)m"
    }
}

// MARK: - Supporting Views

private struct DashboardStatCard: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(color)
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .monospacedDigit()
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .pepinilloGlass(cornerRadius: 12, tint: color, tintOpacity: 0.10)
    }
}

private struct ModeLegendItem: View {
    let systemImage: String
    let minutes: Int
    let color: Color

    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: systemImage)
                .font(.system(size: 8))
                .foregroundStyle(color)
            Text("\(minutes)m")
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }
}
