// EnergyGroupedTaskList.swift
// Pepinillo — Deep Work Companion for Apple
//
// Task list variant that sections tasks by EnergyLevel.
// Shown when TaskListFeature.State.isGroupedByEnergy == true.
//
// Design decisions:
//   • Drag-to-reorder is DISABLED across energy sections because moving a task
//     from one section to another would silently change its energy level —
//     that side-effect belongs in the detail sheet, not an unguarded drag.
//     Within-section reorder is intentionally omitted to avoid confusion;
//     the user can still use the Sort option in the ⋯ menu.
//   • The active EnergyFilter narrows which sections are rendered:
//     if filter != .all, only the matching section is shown.
//   • Empty sections are hidden entirely to avoid visual clutter.
//   • The actionable energy suggestion lives ABOVE the list (PlanTaskList);
//     this view renders sections only — no suggestion surface here (#1022 S2).

import SwiftUI
import ComposableArchitecture

// MARK: - Energy Section Header

struct EnergySectionHeader: View {
    let level: EnergyLevel
    let count: Int

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: level.icon)
                .font(.subheadline)
                .foregroundStyle(level.color)

            Text(level.displayName)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)

            Text("(\(count))")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .padding(.horizontal, 12)
        .padding(.top, 4)
        // Remove default list section header insets
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }
}

// MARK: - Grouped Task List

struct EnergyGroupedTaskList: View {
    @Bindable var store: StoreOf<TaskListFeature>
    let filteredTasks: IdentifiedArrayOf<TaskListFeature.TaskItemState>
    let currentDate: Date
    // «Elegir fecha…» (issue #991 S4) — view-local sheet state.
    @State private var planPickDateTarget: PlanPickTarget?
    @State private var planPickDateDraft: Date = .now

    // Sections order: deep first (highest cognitive demand), then shallow, then admin
    private let sectionOrder: [EnergyLevel] = [.deep, .shallow, .admin]


    private var visibleLevels: [EnergyLevel] {
        switch store.energyFilter {
        case .all:     return sectionOrder
        case .deep:    return [.deep]
        case .shallow: return [.shallow]
        case .admin:   return [.admin]
        }
    }

    var body: some View {
        List {

            ForEach(visibleLevels, id: \.self) { level in
                let sectionTasks = TaskListFeature.sortedPlanTasks(
                    IdentifiedArrayOf(uniqueElements: filteredTasks.filter { $0.energyLevel == level }),
                    sortOrder: store.sortOrder
                )
                if !sectionTasks.isEmpty {
                    // Section header
                    EnergySectionHeader(level: level, count: sectionTasks.count)

                    // Task rows
                    ForEach(sectionTasks) { task in
                        TaskRow(
                            task: task,
                            onTap: { store.send(.taskTapped(task.id)) },
                            onComplete: { store.send(.taskCompleted(task.id)) },
                            onStartFocus: { store.send(.startFocusOnTask(task.id)) },
                            onScheduledForTodayToggled: {
                                store.send(.taskScheduledForToday(task.id, !task.scheduledForToday))
                            },
                            onPlannedDateChanged: { date in
                                store.send(.taskPlannedDateChanged(task.id, date))
                            },
                            onPickDateTapped: {
                                planPickDateDraft = task.plannedDate ?? .now
                                planPickDateTarget = PlanPickTarget(id: task.id)
                            },
                            onEnergyChanged: { newLevel in
                                store.send(.energyLevelChanged(task.id, newLevel))
                            },
                            onRecurrenceChanged: { rule in
                                store.send(.recurrenceChanged(task.id, rule))
                            },
                            onPaywallTapped: { store.send(.paywallRequested) },
                            isProUser: store.isProUser
                        )
                        .equatable()  // Skip re-render when `task` is unchanged (issue #81)
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            Button {
                                store.send(.taskScheduledForToday(task.id, !task.scheduledForToday))
                                HapticManager.impact(.light)
                            } label: {
                                Label(
                                    task.scheduledForToday
                                        ? String(localized: "Remove from Today")
                                        : String(localized: "Add to Today"),
                                    systemImage: task.scheduledForToday ? "minus.circle" : "bolt.circle.fill"
                                )
                            }
                            .tint(task.scheduledForToday ? Color.pepinilloTertiaryLabel : .green)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                store.send(.taskDeleted(task.id))
                            } label: {
                                Label(String(localized: "Delete"), systemImage: "trash")
                            }
                        }
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
                    }
                }
            }
        }
        #if os(macOS)
        .listStyle(.inset)
        #else
        .listStyle(.plain)
        #endif
        .scrollContentBackground(.hidden)
        .background(Color.clear)
        .animation(.smooth(duration: 0.3), value: filteredTasks.map(\.id))
        .refreshable { store.send(.refresh) }
        .sheet(item: $planPickDateTarget) { targetID in
            PlanDatePickerSheet(draft: $planPickDateDraft) { confirmed in
                store.send(.taskPlannedDateChanged(targetID.id, confirmed))
                planPickDateTarget = nil
            } onCancel: {
                planPickDateTarget = nil
            }
        }
    }
}
