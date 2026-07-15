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

    var body: some View {
        ScrollView {
            VStack(spacing: SpacingTokens.sm) {
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
            .padding(.horizontal, SpacingTokens.xs)
            .padding(.top, SpacingTokens.xs)
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
        .padding(.horizontal, SpacingTokens.xs)
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
        HStack(spacing: SpacingTokens.sm) {
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
                color: ModeColors.streak
            )
        }
    }

    // MARK: - Mode Distribution

    private var totalModeMinutes: Int {
        store.pomodoroMinutes + store.flowtimeMinutes + store.timeBlockMinutes + store.stopwatchMinutes
    }

    private var modeDistributionView: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xs) {
            Text(String(localized: "Modes"))
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.leading, SpacingTokens.xs)

            // Stacked bar
            GeometryReader { geo in
                let total = max(CGFloat(totalModeMinutes), 1)
                HStack(spacing: 1) {
                    let modes: [(Int, Color)] = [
                        (store.pomodoroMinutes, ModeColors.pomodoro),
                        (store.flowtimeMinutes, ModeColors.flowtime),
                        (store.timeBlockMinutes, ModeColors.timeBlock),
                        (store.stopwatchMinutes, ModeColors.stopwatch),
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
            .padding(.horizontal, SpacingTokens.xs)

            // Legend
            HStack(spacing: 6) {
                if store.pomodoroMinutes > 0 {
                    ModeLegendItem(emoji: "🍅", minutes: store.pomodoroMinutes, color: ModeColors.pomodoro)
                }
                if store.flowtimeMinutes > 0 {
                    ModeLegendItem(emoji: "🌊", minutes: store.flowtimeMinutes, color: ModeColors.flowtime)
                }
                if store.timeBlockMinutes > 0 {
                    ModeLegendItem(emoji: "📦", minutes: store.timeBlockMinutes, color: ModeColors.timeBlock)
                }
                if store.stopwatchMinutes > 0 {
                    ModeLegendItem(emoji: "⏱️", minutes: store.stopwatchMinutes, color: ModeColors.stopwatch)
                }
            }
            .padding(.horizontal, SpacingTokens.xs)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, SpacingTokens.xs)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: GlassCornerRadius.tile, style: .continuous))
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
        .padding(.horizontal, SpacingTokens.sm)
        .padding(.vertical, SpacingTokens.sm)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: GlassCornerRadius.tile, style: .continuous))
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
        .padding(.vertical, SpacingTokens.sm)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: GlassCornerRadius.tile, style: .continuous))
    }
}

private struct ModeLegendItem: View {
    let emoji: String
    let minutes: Int
    let color: Color

    var body: some View {
        HStack(spacing: 2) {
            Text(emoji)
                .font(.system(size: 8))
            Text("\(minutes)m")
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }
}
