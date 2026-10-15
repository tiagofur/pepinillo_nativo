// TaskAnalyticsFeature.swift
// Pepinillo — Deep Work Companion for Apple
//
// TCA Reducer for per-task productivity analytics.
// Fetches and displays focus session data for a specific task.

import Foundation
import ComposableArchitecture

@Reducer
struct TaskAnalyticsFeature {

    @ObservableState
    struct State: Equatable {
        let taskID: UUID
        let taskTitle: String
        var analytics: TaskAnalyticsDTO?
        var isLoading: Bool = false
    }

    enum Action: Equatable {
        case onAppear
        case analyticsLoaded(TaskAnalyticsDTO)
        case analyticsFailed
        case dismiss
    }

    @Dependency(\.persistenceClient) var persistenceClient
    @Dependency(\.dismiss) var dismiss

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {

            case .onAppear:
                guard !state.isLoading else { return .none }
                state.isLoading = true
                let taskID = state.taskID
                return .run { send in
                    do {
                        let analytics = try await persistenceClient.fetchTaskAnalytics(taskID)
                        await send(.analyticsLoaded(analytics))
                    } catch {
                        await send(.analyticsFailed)
                    }
                }

            case .analyticsFailed:
                // The sheet already renders an empty state when analytics is
                // nil — just release the spinner (S1).
                state.isLoading = false
                return .none

            case .analyticsLoaded(let analytics):
                state.analytics = analytics
                state.isLoading = false
                return .none

            case .dismiss:
                return .run { _ in await dismiss() }
            }
        }
    }
}
