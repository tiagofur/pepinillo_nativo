// MonthlyReviewFeature.swift
// Pepinillo — Deep Work Companion for Apple
//
// TCA Reducer for the Monthly Review screen.
// Compares current month vs previous month, shows trends, dominant mode, best week,
// top 3 tasks by focus time, and mode distribution.
// Conversion driver for Pro subscription.

import Foundation
import ComposableArchitecture

@Reducer
struct MonthlyReviewFeature {

    @ObservableState
    struct State: Equatable {
        var isLoading: Bool = false

        // Current month
        var currentMonthMinutes: Int = 0
        var currentMonthSessions: Int = 0
        var currentMonthDominantMode: FocusMode?

        // Previous month
        var previousMonthMinutes: Int = 0
        var previousMonthSessions: Int = 0

        // Trends
        var minutesDelta: Int = 0
        var sessionsDelta: Int = 0
        var minutesTrend: Trend = .neutral
        var sessionsTrend: Trend = .neutral

        // Best week within month
        var bestWeekLabel: String?
        var bestWeekMinutes: Int = 0

        // Top 3 tasks by focus time
        var topTasks: [TopTask] = []

        // Mode distribution this month
        var modeDistribution: [ModeMinutes] = []

        // Completion rate
        var completionRate: Double = 0

        enum Trend: Equatable {
            case up, down, neutral
        }

        struct TopTask: Identifiable, Equatable {
            let id: UUID
            let title: String
            let minutes: Int
        }

        struct ModeMinutes: Identifiable, Equatable {
            let id: String
            let mode: FocusMode
            let minutes: Int
        }
    }

    enum Action: Equatable {
        case onAppear
        case dataLoaded(MonthlyData)
        case dismiss
    }

    struct MonthlyData: Equatable, Sendable {
        let currentMonthMinutes: Int
        let currentMonthSessions: Int
        let previousMonthMinutes: Int
        let previousMonthSessions: Int
        let currentMonthDominantMode: FocusMode?
        let bestWeekLabel: String?
        let bestWeekMinutes: Int
        let topTasks: [State.TopTask]
        let modeDistribution: [State.ModeMinutes]
        let completionRate: Double
    }

    @Dependency(\.persistenceClient) var persistence

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {

            case .onAppear:
                state.isLoading = true
                return .run { send in
                    let calendar = Calendar.current
                    let today = calendar.startOfDay(for: Date.now)

                    // Current month: 1st of this month to today
                    let currentMonthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: today))!
                    let endOfToday = calendar.date(byAdding: .day, value: 1, to: today)!

                    // Previous month: 1st of previous month to 1st of current month
                    let previousMonthStart = calendar.date(byAdding: .month, value: -1, to: currentMonthStart)!
                    let previousMonthEnd = currentMonthStart

                    let currentSessions = try await persistence.fetchSessions(currentMonthStart, endOfToday)
                    let previousSessions = try await persistence.fetchSessions(previousMonthStart, previousMonthEnd)

                    // Aggregate current month
                    var currentTotal = 0
                    var currentCount = 0
                    var completedCount = 0
                    var modeSecs: [FocusMode: Int] = [:]
                    var weeklyTotals: [Int: Int] = [:] // weekOfMonth -> seconds
                    var taskSecs: [UUID: Int] = [:]

                    for record in currentSessions {
                        let secs = Int(record.actualDuration)
                        currentTotal += secs
                        currentCount += 1

                        if record.wasCompleted { completedCount += 1 }

                        if let mode = FocusMode(rawValue: record.mode) {
                            modeSecs[mode, default: 0] += secs
                        }

                        let weekOfMonth = calendar.component(.weekOfMonth, from: record.startedAt)
                        weeklyTotals[weekOfMonth, default: 0] += secs

                        if let taskID = record.taskID {
                            taskSecs[taskID, default: 0] += secs
                        }
                    }

                    // Aggregate previous month
                    var prevTotal = 0
                    var prevCount = 0
                    for record in previousSessions {
                        prevTotal += Int(record.actualDuration)
                        prevCount += 1
                    }

                    // Best week within month
                    let bestWeek = weeklyTotals.max(by: { $0.value < $1.value })
                    let bestWeekLabel: String? = bestWeek.map { String(localized: "Week \($0.key)") }
                    let bestWeekMinutes = (bestWeek?.value ?? 0) / 60

                    // Top 3 tasks by focus time
                    let sortedTasks = taskSecs.sorted(by: { $0.value > $1.value }).prefix(3)
                    let allTasks = try await persistence.fetchTasks()
                    let taskMap = Dictionary(uniqueKeysWithValues: allTasks.map { ($0.id, $0.title) })
                    let topTasks = sortedTasks.map { (taskID, secs) in
                        State.TopTask(
                            id: taskID,
                            title: taskMap[taskID] ?? String(localized: "Unknown Task"),
                            minutes: secs / 60
                        )
                    }

                    // Dominant mode
                    let dominant = modeSecs.max(by: { $0.value < $1.value })?.key

                    // Mode distribution
                    let distribution = modeSecs
                        .sorted(by: { $0.value > $1.value })
                        .map { State.ModeMinutes(id: $0.key.rawValue, mode: $0.key, minutes: $0.value / 60) }

                    // Completion rate
                    let completionRate = currentCount > 0 ? Double(completedCount) / Double(currentCount) : 0

                    await send(.dataLoaded(MonthlyData(
                        currentMonthMinutes: currentTotal / 60,
                        currentMonthSessions: currentCount,
                        previousMonthMinutes: prevTotal / 60,
                        previousMonthSessions: prevCount,
                        currentMonthDominantMode: dominant,
                        bestWeekLabel: bestWeekLabel,
                        bestWeekMinutes: bestWeekMinutes,
                        topTasks: topTasks,
                        modeDistribution: distribution,
                        completionRate: completionRate
                    )))
                }

            case .dataLoaded(let data):
                state.isLoading = false
                state.currentMonthMinutes = data.currentMonthMinutes
                state.currentMonthSessions = data.currentMonthSessions
                state.previousMonthMinutes = data.previousMonthMinutes
                state.previousMonthSessions = data.previousMonthSessions
                state.currentMonthDominantMode = data.currentMonthDominantMode
                state.bestWeekLabel = data.bestWeekLabel
                state.bestWeekMinutes = data.bestWeekMinutes
                state.topTasks = data.topTasks
                state.modeDistribution = data.modeDistribution
                state.completionRate = data.completionRate

                state.minutesDelta = data.currentMonthMinutes - data.previousMonthMinutes
                state.sessionsDelta = data.currentMonthSessions - data.previousMonthSessions
                state.minutesTrend = data.currentMonthMinutes > data.previousMonthMinutes ? .up
                    : data.currentMonthMinutes < data.previousMonthMinutes ? .down : .neutral
                state.sessionsTrend = data.currentMonthSessions > data.previousMonthSessions ? .up
                    : data.currentMonthSessions < data.previousMonthSessions ? .down : .neutral
                return .none

            case .dismiss:
                return .none
            }
        }
    }
}
