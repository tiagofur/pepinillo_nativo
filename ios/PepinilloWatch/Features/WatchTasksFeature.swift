// WatchTasksFeature.swift
// Pepinillo — Deep Work Companion for Apple
//
// TCA Reducer for the Apple Watch tasks screen.
// Displays today's tasks synced from iOS, allows linking a task
// to the current focus session and toggling completion.

import Foundation
import ComposableArchitecture

// MARK: - WatchTasksFeature

@Reducer
struct WatchTasksFeature {

    // MARK: - State

    @ObservableState
    struct State: Equatable {
        var tasks: [WatchTaskItem] = []
        var linkedTaskID: UUID? = nil
        /// Ignore out-of-order task list payloads (#243).
        var lastTasksReceivedAt: TimeInterval = 0
    }

    // MARK: - Action

    enum Action: Equatable {
        // User interactions
        case taskTapped(UUID)
        case taskLongPressed(UUID)
        case setCompleted(UUID, Bool)

        // Cross-feature (handled by parent WatchAppFeature)
        case taskLinked(UUID, String)
        case taskUnlinked

        // Received from parent
        case tasksReceived([WatchTaskItem], sentAt: TimeInterval)
    }

    // MARK: - Reducer

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {

            case .taskTapped(let id):
                guard let task = state.tasks.first(where: { $0.id == id }) else { return .none }
                return .send(.setCompleted(id, !task.isCompleted))

            case .taskLongPressed(let id):
                // Long press links/unlinks task to timer
                if state.linkedTaskID == id {
                    state.linkedTaskID = nil
                    return .send(.taskUnlinked)
                }
                guard let task = state.tasks.first(where: { $0.id == id }),
                      !task.isCompleted else { return .none }
                state.linkedTaskID = id
                return .send(.taskLinked(id, task.title))

            case .setCompleted(let id, let isCompleted):
                guard let index = state.tasks.firstIndex(where: { $0.id == id }) else { return .none }
                let task = state.tasks[index]
                guard task.isCompleted != isCompleted else { return .none }
                state.tasks[index] = WatchTaskItem(
                    id: task.id,
                    title: task.title,
                    isCompleted: isCompleted,
                    priority: task.priority,
                    estimatedPomodoros: task.estimatedPomodoros,
                    completedPomodoros: task.completedPomodoros
                )
                // The actual command is sent by WatchAppFeature
                return .none

            case .taskLinked, .taskUnlinked:
                return .none

            case .tasksReceived(let items, let sentAt):
                guard sentAt >= state.lastTasksReceivedAt else { return .none }
                state.lastTasksReceivedAt = sentAt
                state.tasks = items
                return .none
            }
        }
    }
}