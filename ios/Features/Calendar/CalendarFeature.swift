// CalendarFeature.swift
// Pepinillo — Deep Work Companion for Apple
//
// TCA Reducer for the Calendar screen.
// Monthly view showing focus activity and tasks per day.

import Foundation
import ComposableArchitecture

@Reducer
struct CalendarFeature {

    @ObservableState
    struct State: Equatable {
        var displayedMonth: Date = {
            let cal = Calendar.current
            let comps = cal.dateComponents([.year, .month], from: Date.now)
            return cal.date(from: comps) ?? Date.now
        }()
        var selectedDate: Date? = nil
        var isLoading: Bool = false

        // Days with focus activity (for dot indicators)
        var activityDays: Set<DateComponents> = []

        // Selected day detail
        var selectedDayDetail: DayDetail? = nil

        // MARK: - Nested Types

        struct DayDetail: Equatable {
            let date: Date
            let totalFocusMinutes: Int
            let sessionsCompleted: Int
            let sessions: [SessionSummary]
            let tasks: [TaskSummary]
        }

        struct SessionSummary: Equatable, Identifiable {
            let id: UUID
            let startedAt: Date
            let mode: String
            let durationMinutes: Int
            let wasCompleted: Bool
        }

        struct TaskSummary: Equatable, Identifiable {
            let id: UUID
            let title: String
            let isCompleted: Bool
            let priority: TaskPriority
            let isDue: Bool
            let wasCompletedToday: Bool
        }
    }

    enum Action: Equatable {
        case onAppear
        case monthChanged(Date)
        case daySelected(Date)
        case monthDataLoaded(Set<DateComponents>)
        case dayDetailLoaded(State.DayDetail)
    }

    @Dependency(\.persistenceClient) var persistence

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                guard !state.isLoading else { return .none }
                state.isLoading = true
                return loadMonthData(for: state.displayedMonth)

            case .monthChanged(let newMonth):
                state.displayedMonth = newMonth
                state.selectedDate = nil
                state.selectedDayDetail = nil
                state.isLoading = true
                return loadMonthData(for: newMonth)

            case .daySelected(let date):
                state.selectedDate = date
                return loadDayDetail(for: date)

            case .monthDataLoaded(let days):
                state.isLoading = false
                state.activityDays = days
                return .none

            case .dayDetailLoaded(let detail):
                state.selectedDayDetail = detail
                return .none
            }
        }
    }

    // MARK: - Effects

    private func loadMonthData(for month: Date) -> Effect<Action> {
        .run { send in
            let calendar = Calendar.current
            let comps = calendar.dateComponents([.year, .month], from: month)
            guard let start = calendar.date(from: comps),
                  let end = calendar.date(byAdding: .month, value: 1, to: start) else {
                await send(.monthDataLoaded([]))
                return
            }

            let sessions: [SessionRecordDTO]
            let tasks: [TaskItemDTO]
            do {
                sessions = try await persistence.fetchSessions(start, end)
                tasks = try await persistence.fetchTasks()
            } catch {
                // Degrade to an empty month (same as the invalid-date guard
                // above) instead of wedging isLoading on forever (S1).
                await send(.monthDataLoaded([]))
                return
            }

            var daySet = Set<DateComponents>()

            for session in sessions {
                let dc = calendar.dateComponents([.year, .month, .day], from: session.startedAt)
                daySet.insert(dc)
            }

            // Also mark days that have tasks due
            for task in tasks {
                if let dueDate = task.dueDate,
                   dueDate >= start && dueDate < end {
                    let dc = calendar.dateComponents([.year, .month, .day], from: dueDate)
                    daySet.insert(dc)
                }
            }

            await send(.monthDataLoaded(daySet))
        }
    }

    private func loadDayDetail(for date: Date) -> Effect<Action> {
        .run { send in
            let calendar = Calendar.current
            let startOfDay = calendar.startOfDay(for: date)
            guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else { return }

            async let sessionsFetch = persistence.fetchSessions(startOfDay, endOfDay)
            async let tasksFetch = persistence.fetchTasks()

            let loaded: ([SessionRecordDTO], [TaskItemDTO])
            do {
                loaded = try await (sessionsFetch, tasksFetch)
            } catch {
                // Degrade to an empty day rather than leaving no detail (S1).
                await send(.dayDetailLoaded(State.DayDetail(date: date, totalFocusMinutes: 0, sessionsCompleted: 0, sessions: [], tasks: [])))
                return
            }
            let (sessions, allTasks) = loaded

            let relevantTasks = allTasks.compactMap { task -> State.TaskSummary? in
                let isDue = task.dueDate.map { calendar.isDate($0, inSameDayAs: date) } ?? false
                let wasCompletedToday = task.completedAt.map { calendar.isDate($0, inSameDayAs: date) } ?? false
                guard isDue || wasCompletedToday else { return nil }
                return State.TaskSummary(
                    id: task.id,
                    title: task.title,
                    isCompleted: task.isCompleted,
                    priority: task.priority,
                    isDue: isDue,
                    wasCompletedToday: wasCompletedToday
                )
            }

            let sessionSummaries = sessions.map { s in
                State.SessionSummary(
                    id: s.id,
                    startedAt: s.startedAt,
                    mode: s.mode,
                    durationMinutes: max(1, Int(s.actualDuration) / 60),
                    wasCompleted: s.wasCompleted
                )
            }

            let totalMinutes = sessions.reduce(0) { $0 + Int($1.actualDuration) } / 60

            let detail = State.DayDetail(
                date: date,
                totalFocusMinutes: totalMinutes,
                sessionsCompleted: sessions.filter(\.wasCompleted).count,
                sessions: sessionSummaries,
                tasks: relevantTasks
            )

            await send(.dayDetailLoaded(detail))
        }
    }
}
