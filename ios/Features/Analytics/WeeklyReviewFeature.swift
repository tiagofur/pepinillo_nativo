// WeeklyReviewFeature.swift
// Pepinillo — Deep Work Companion for Apple
//
// TCA Reducer for the Weekly Review screen.
// Compares current week vs previous week, shows trends, dominant mode, best day.
// Conversion driver for Pro subscription.

import Foundation
import ComposableArchitecture

@Reducer
struct WeeklyReviewFeature {

    @ObservableState
    struct State: Equatable {
        var isLoading: Bool = false

        // Current week
        var currentWeekMinutes: Int = 0
        var currentWeekSessions: Int = 0
        var currentWeekDominantMode: FocusMode?

        // Previous week
        var previousWeekMinutes: Int = 0
        var previousWeekSessions: Int = 0

        // Trends
        var minutesDelta: Int = 0           // positive = improvement
        var sessionsDelta: Int = 0
        var minutesTrend: Trend = .neutral
        var sessionsTrend: Trend = .neutral

        // Best day
        var bestDayName: String?
        var bestDayMinutes: Int = 0

        // Per-day breakdown (Mon-Sun)
        var dailyBreakdown: [DayBreakdown] = []

        // Streak
        var currentStreakDays: Int = 0

        // Mode distribution this week
        var modeDistribution: [ModeMinutes] = []

        enum Trend: Equatable {
            case up, down, neutral
        }

        struct DayBreakdown: Identifiable, Equatable {
            let id: Date
            let dayName: String
            let minutes: Int
            let sessions: Int
        }

        struct ModeMinutes: Identifiable, Equatable {
            let id: String
            let mode: FocusMode
            let minutes: Int
        }
    }

    enum Action: Equatable {
        case onAppear
        case dataLoaded(WeeklyData)
        case dismiss
    }

    struct WeeklyData: Equatable, Sendable {
        let currentWeekMinutes: Int
        let currentWeekSessions: Int
        let previousWeekMinutes: Int
        let previousWeekSessions: Int
        let currentWeekDominantMode: FocusMode?
        let bestDayName: String?
        let bestDayMinutes: Int
        let dailyBreakdown: [State.DayBreakdown]
        let modeDistribution: [State.ModeMinutes]
        let currentStreakDays: Int
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
                    let endOfToday = calendar.date(byAdding: .day, value: 1, to: today)!

                    // Current week: last 7 days (including today)
                    let currentStart = calendar.date(byAdding: .day, value: -6, to: today)!
                    // Previous week: 7 days before that
                    let previousStart = calendar.date(byAdding: .day, value: -13, to: today)!
                    let previousEnd = currentStart

                    let currentSessions = try await persistence.fetchSessions(currentStart, endOfToday)
                    let previousSessions = try await persistence.fetchSessions(previousStart, previousEnd)

                    // Aggregate current week
                    var currentTotal = 0
                    var currentCount = 0
                    var modeSecs: [FocusMode: Int] = [:]
                    var dailyMap: [Date: (Int, Int)] = [:] // (seconds, sessions)
                    let dayFormatter = DateFormatter()
                    dayFormatter.dateFormat = "EEEE"

                    for record in currentSessions {
                        let secs = Int(record.actualDuration)
                        currentTotal += secs
                        currentCount += 1
                        let day = calendar.startOfDay(for: record.startedAt)
                        let (prevSecs, prevSes) = dailyMap[day] ?? (0, 0)
                        dailyMap[day] = (prevSecs + secs, prevSes + 1)

                        if let mode = FocusMode(rawValue: record.mode) {
                            modeSecs[mode, default: 0] += secs
                        }
                    }

                    // Aggregate previous week
                    var prevTotal = 0
                    var prevCount = 0
                    for record in previousSessions {
                        prevTotal += Int(record.actualDuration)
                        prevCount += 1
                    }

                    // Build daily breakdown
                    var breakdown: [State.DayBreakdown] = []
                    for dayOffset in 0..<7 {
                        let date = calendar.date(byAdding: .day, value: -(6 - dayOffset), to: today)!
                        let (secs, ses) = dailyMap[date] ?? (0, 0)
                        breakdown.append(State.DayBreakdown(
                            id: date,
                            dayName: dayFormatter.string(from: date),
                            minutes: secs / 60,
                            sessions: ses
                        ))
                    }

                    // Best day
                    let best = breakdown.max(by: { $0.minutes < $1.minutes })

                    // Dominant mode
                    let dominant = modeSecs.max(by: { $0.value < $1.value })?.key

                    // Mode distribution
                    let distribution = modeSecs
                        .sorted(by: { $0.value > $1.value })
                        .map { State.ModeMinutes(id: $0.key.rawValue, mode: $0.key, minutes: $0.value / 60) }

                    // Streak
                    let prefs = try await persistence.fetchPreferences()

                    await send(.dataLoaded(WeeklyData(
                        currentWeekMinutes: currentTotal / 60,
                        currentWeekSessions: currentCount,
                        previousWeekMinutes: prevTotal / 60,
                        previousWeekSessions: prevCount,
                        currentWeekDominantMode: dominant,
                        bestDayName: best?.dayName,
                        bestDayMinutes: best?.minutes ?? 0,
                        dailyBreakdown: breakdown,
                        modeDistribution: distribution,
                        currentStreakDays: prefs.currentStreakDays
                    )))
                }

            case .dataLoaded(let data):
                state.isLoading = false
                state.currentWeekMinutes = data.currentWeekMinutes
                state.currentWeekSessions = data.currentWeekSessions
                state.previousWeekMinutes = data.previousWeekMinutes
                state.previousWeekSessions = data.previousWeekSessions
                state.currentWeekDominantMode = data.currentWeekDominantMode
                state.bestDayName = data.bestDayName
                state.bestDayMinutes = data.bestDayMinutes
                state.dailyBreakdown = data.dailyBreakdown
                state.modeDistribution = data.modeDistribution
                state.currentStreakDays = data.currentStreakDays

                state.minutesDelta = data.currentWeekMinutes - data.previousWeekMinutes
                state.sessionsDelta = data.currentWeekSessions - data.previousWeekSessions
                state.minutesTrend = data.currentWeekMinutes > data.previousWeekMinutes ? .up
                    : data.currentWeekMinutes < data.previousWeekMinutes ? .down : .neutral
                state.sessionsTrend = data.currentWeekSessions > data.previousWeekSessions ? .up
                    : data.currentWeekSessions < data.previousWeekSessions ? .down : .neutral
                return .none

            case .dismiss:
                return .none
            }
        }
    }
}
