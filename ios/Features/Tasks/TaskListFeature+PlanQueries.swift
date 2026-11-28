// TaskListFeature+PlanQueries.swift
// Pepinillo — Deep Work Companion for Apple
//
// Plan bucket queries and the planned-date write seam, extracted from
// TaskListFeature (cognitive budget, issue #991 PR-b review).

import ComposableArchitecture
import Foundation
import SwiftUI
import WidgetKit

extension TaskListFeature {

    /// Writes a planned date full-fidelity: fetch → `updating` (never a partial
    /// DTO rebuild, issue #178) → save. The legacy `scheduledForToday` boolean
    /// is derived so pre-PR-C surfaces (widget, Siri, Mac Today) keep reading a
    /// true «Hoy» until they switch to the unified rule (issue #991).
    static func persistPlannedDate(
        id: UUID,
        planned: Date?,
        now: Date,
        state: inout State,
        persistence: PersistenceClient
    ) -> Effect<Action> {
        guard let snapshot = state.tasks[id: id] else { return .none }
        let flag = TaskPlanning.legacyFlag(plannedDate: planned, now: now)
        state.tasks[id: id]?.plannedDate = planned
        state.tasks[id: id]?.scheduledForToday = flag
        return .run { send in
            do {
                if let item = try await persistence.fetchTask(id) {
                    let updated = item.updating(
                        plannedDate: .some(planned),
                        scheduledForToday: flag
                    )
                    try await persistence.saveTask(updated)
                    WidgetCenter.shared.reloadTimelines(ofKind: "TasksHomeScreenWidget")
                }
            } catch {
                await send(.mutationFailed(.update(
                    task: snapshot,
                    message: error.localizedDescription
                )))
            }
        }
    }

    /// Default scheduling fields for Plan quick-add based on the active filter (issue #180).
    /// S5 (#991): Upcoming inherits a planned date, not a deadline.
    static func planQuickAddDefaults(
        for filter: PlanFilter,
        now: Date = .now
    ) -> (plannedDate: Date?, dueDate: Date?) {
        switch filter {
        case .today:
            return (TaskPlanning.plannedDay(now), nil)
        case .inbox, .completed:
            return (nil, nil)
        case .upcoming:
            return (TaskPlanning.tomorrow(from: now), nil)
        }
    }

    /// Tasks visible for a Plan sidebar filter. Shared by PlanTaskList and
    /// `taskMoved` so drag indices map to the same subset (issue #179).
    /// Applies the Plan sort menu to a filtered task list (#185).
    static func sortedPlanTasks(
        _ tasks: IdentifiedArrayOf<TaskItemState>,
        sortOrder: SortOrder
    ) -> IdentifiedArrayOf<TaskItemState> {
        let sorted = tasks.sorted { lhs, rhs in
            if lhs.isCompleted != rhs.isCompleted { return !lhs.isCompleted }
            switch sortOrder {
            case .custom:
                if lhs.sortOrder != rhs.sortOrder { return lhs.sortOrder < rhs.sortOrder }
            case .priority:
                if lhs.priority != rhs.priority { return lhs.priority > rhs.priority }
            case .dueDate:
                switch (lhs.dueDate, rhs.dueDate) {
                case (nil, nil): break
                case (nil, _): return false
                case (_, nil): return true
                case let (l?, r?) where l != r: return l < r
                default: break
                }
            case .energy:
                let lIdx = energySortIndex(lhs.energyLevel)
                let rIdx = energySortIndex(rhs.energyLevel)
                if lIdx != rIdx { return lIdx < rIdx }
            case .created:
                if lhs.createdAt != rhs.createdAt { return lhs.createdAt > rhs.createdAt }
            }
            if lhs.createdAt != rhs.createdAt { return lhs.createdAt > rhs.createdAt }
            return lhs.sortOrder < rhs.sortOrder
        }
        return IdentifiedArrayOf(uniqueElements: sorted)
    }

    private static func energySortIndex(_ level: EnergyLevel) -> Int {
        switch level {
        case .deep: return 0
        case .shallow: return 1
        case .admin: return 2
        }
    }

    static func planFilteredTasks(
        _ tasks: IdentifiedArrayOf<TaskItemState>,
        filter: PlanFilter,
        now: Date = .now
    ) -> IdentifiedArrayOf<TaskItemState> {
        // Recurring templates are series anchors — instances appear in Plan lists (#188).
        let visible = tasks.filter { !$0.isRecurringTemplate }
        // Unified «Hoy» rule (issue #991 S2): one resolver for the whole app.
        return visible.filter { task in
            let bucket = TaskPlanning.bucket(
                plannedDate: task.plannedDate,
                dueDate: task.dueDate,
                scheduledForToday: task.scheduledForToday,
                isCompleted: task.isCompleted,
                now: now
            )
            switch (filter, bucket) {
            case (.today, .today):
                return true
            case (.inbox, .inbox):
                return true
            case (.upcoming, .upcoming):
                // #182: no one-week cap — Upcoming holds every future date.
                return true
            case (.completed, .completed):
                return true
            default:
                return false
            }
        }
    }

    /// The unfiltered Today set the energy suggestion's S3 candidate check
    /// reads — computed before any energy or search narrowing (#990). One
    /// function for PlanTaskList (iOS) and MacPlanView (macOS) so both
    /// platforms decide "the suggested level has candidates" identically.
    static func todayUnfilteredTasks(
        _ tasks: IdentifiedArrayOf<TaskItemState>
    ) -> IdentifiedArrayOf<TaskItemState> {
        planFilteredTasks(tasks, filter: .today)
    }
}
