// WatchAppFeature.swift
// Pepinillo — Deep Work Companion for Apple
//
// Root TCA Reducer for the watchOS app. Composes Timer, Tasks, and Dashboard
// features. Manages WatchConnectivity message routing and tab selection.

import Foundation
import ComposableArchitecture
import WidgetKit
#if os(watchOS)
import WatchKit
#endif

// MARK: - WatchAppFeature

@Reducer
struct WatchAppFeature {

    // MARK: - State

    @ObservableState
    struct State: Equatable {
        var selectedTab: WatchTab = .timer
        var timer = WatchTimerFeature.State()
        var tasks = WatchTasksFeature.State()
        var dashboard = WatchDashboardFeature.State()

        var isConnected: Bool = false
    }

    enum WatchTab: Int, Equatable {
        case dashboard = 0
        case timer = 1
        case tasks = 2
    }

    // MARK: - Action

    enum Action: Equatable {
        case timer(WatchTimerFeature.Action)
        case tasks(WatchTasksFeature.Action)
        case dashboard(WatchDashboardFeature.Action)
        case tabSelected(WatchTab)
        case onAppear

        // WatchConnectivity messages
        case sessionStateReceived(WatchSessionState)
        case statsReceived(todayMinutes: Int, sessions: Int, streak: Int)
        case tasksReceived([WatchTaskItem])
        case dashboardStatsReceived(WatchDashboardStats)
        case connectivityChanged(Bool)
    }

    // MARK: - Dependencies

    @Dependency(\.watchConnectivityClient) var watchClient

    // MARK: - Reducer

    var body: some ReducerOf<Self> {
        Scope(state: \.timer, action: \.timer) {
            WatchTimerFeature()
        }
        Scope(state: \.tasks, action: \.tasks) {
            WatchTasksFeature()
        }
        Scope(state: \.dashboard, action: \.dashboard) {
            WatchDashboardFeature()
        }
        Reduce { state, action in
            switch action {

            case .onAppear:
                return .run { send in
                    let stream = await watchClient.receiveMessages()
                    for await message in stream {
                        switch message {
                        case .sessionState(let s):
                            await send(.sessionStateReceived(s))
                        case .stats(let m, let c, let sk):
                            await send(.statsReceived(todayMinutes: m, sessions: c, streak: sk))
                        case .tasks(let items):
                            await send(.tasksReceived(items))
                        case .dashboardStats(let stats):
                            await send(.dashboardStatsReceived(stats))
                        case .connectivityStatus(let connected):
                            await send(.connectivityChanged(connected))
                        case .command:
                            break
                        }
                    }
                }

            case .tabSelected(let tab):
                state.selectedTab = tab
                return .none

            // MARK: - Route connectivity messages to child features

            case .sessionStateReceived(let s):
                // Auto-switch to timer tab when a session starts
                if s.isActive && !state.timer.isSessionActive {
                    state.selectedTab = .timer
                }
                return .send(.timer(.sessionStateReceived(s)))

            case .statsReceived(let minutes, let sessions, let streak):
                return .merge(
                    .send(.timer(.statsReceived(todayMinutes: minutes, sessions: sessions, streak: streak))),
                    .send(.dashboard(.statsReceived(todayMinutes: minutes, sessions: sessions, streak: streak)))
                )

            case .tasksReceived(let items):
                return .merge(
                    .send(.tasks(.tasksReceived(items))),
                    .run { _ in
                        Self.persistTasksForComplication(items)
                        WidgetCenter.shared.reloadTimelines(ofKind: "PepinilloTasksComplication")
                    }
                )

            case .dashboardStatsReceived(let stats):
                return .send(.dashboard(.dashboardStatsReceived(stats)))

            case .connectivityChanged(let connected):
                state.isConnected = connected
                return .merge(
                    .send(.timer(.connectivityChanged(connected))),
                    // Request tasks and dashboard on connect
                    connected ? .run { [watchClient] _ in
                        await watchClient.sendCommand(.requestTasks)
                        await watchClient.sendCommand(.requestDashboard)
                    } : .none
                )

            // MARK: - Task linking from tasks tab → timer

            case .tasks(.taskLinked(let id, let title)):
                state.timer.linkedTaskID = id.uuidString
                state.timer.linkedTaskTitle = title
                state.selectedTab = .timer
                return .run { [watchClient] _ in
                    await watchClient.sendCommand(.linkTask(id: id.uuidString))
                }

            case .tasks(.taskUnlinked):
                state.timer.linkedTaskID = nil
                state.timer.linkedTaskTitle = nil
                return .run { [watchClient] _ in
                    await watchClient.sendCommand(.unlinkTask)
                }

            case .tasks(.toggleCompleted(let id)):
                return .run { [watchClient] _ in
                    await watchClient.sendCommand(.toggleTaskCompleted(id: id.uuidString))
                }

            case .timer, .tasks, .dashboard:
                return .none
            }
        }
    }

    // MARK: - UserDefaults Persistence (for Tasks Complication)
    //
    // Must use the app group suite — complications are a separate process and
    // cannot read UserDefaults.standard written by the watch app.

    private static var appGroupDefaults: UserDefaults? {
        UserDefaults(suiteName: "group.com.pepinillo.app")
    }

    private static func persistTasksForComplication(_ tasks: [WatchTaskItem]) {
        guard let defaults = appGroupDefaults else { return }
        let completedCount = tasks.filter(\.isCompleted).count
        defaults.set(completedCount, forKey: WatchStatsKeys.tasksCompletedCount)
        defaults.set(tasks.count, forKey: WatchStatsKeys.tasksTotalCount)

        // Encode tasks as JSON array for the complication to read
        let encoded: [[String: Any]] = tasks.map { task in
            [
                "id": task.id.uuidString,
                "title": task.title,
                "isCompleted": task.isCompleted,
                "priority": task.priority,
                "estimatedPomodoros": task.estimatedPomodoros,
                "completedPomodoros": task.completedPomodoros,
            ]
        }
        if let data = try? JSONSerialization.data(withJSONObject: encoded) {
            defaults.set(data, forKey: WatchStatsKeys.tasksJSON)
        }
    }
}
