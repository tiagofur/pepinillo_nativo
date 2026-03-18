// WatchDashboardFeature.swift
// Pepinillo — Deep Work Companion for Apple
//
// TCA Reducer for the Apple Watch dashboard screen.
// Shows daily focus summary: time, sessions, tasks, streak,
// and per-mode breakdown.

import Foundation
import ComposableArchitecture

// MARK: - WatchDashboardFeature

@Reducer
struct WatchDashboardFeature {

    // MARK: - State

    @ObservableState
    struct State: Equatable {
        var todayFocusMinutes: Int = 0
        var sessionsCompleted: Int = 0
        var tasksCompleted: Int = 0
        var tasksTotal: Int = 0
        var streakDays: Int = 0

        // Per-mode breakdown (minutes)
        var pomodoroMinutes: Int = 0
        var flowtimeMinutes: Int = 0
        var timeBlockMinutes: Int = 0
        var stopwatchMinutes: Int = 0

        var longestSessionMinutes: Int = 0
    }

    // MARK: - Action

    enum Action: Equatable {
        case onAppear

        // Received from parent
        case statsReceived(todayMinutes: Int, sessions: Int, streak: Int)
        case dashboardStatsReceived(WatchDashboardStats)
    }

    // MARK: - Dependencies

    @Dependency(\.watchConnectivityClient) var watchClient

    // MARK: - Reducer

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {

            case .onAppear:
                return .run { [watchClient] _ in
                    await watchClient.sendCommand(.requestDashboard)
                }

            case .statsReceived(let minutes, let sessions, let streak):
                state.todayFocusMinutes = minutes
                state.sessionsCompleted = sessions
                state.streakDays = streak
                return .none

            case .dashboardStatsReceived(let stats):
                state.todayFocusMinutes = stats.todayMinutes
                state.sessionsCompleted = stats.sessionsCompleted
                state.tasksCompleted = stats.tasksCompleted
                state.tasksTotal = stats.tasksTotal
                state.streakDays = stats.streakDays
                state.pomodoroMinutes = stats.pomodoroMinutes
                state.flowtimeMinutes = stats.flowtimeMinutes
                state.timeBlockMinutes = stats.timeBlockMinutes
                state.stopwatchMinutes = stats.stopwatchMinutes
                state.longestSessionMinutes = stats.longestSessionMinutes
                return .none
            }
        }
    }
}
