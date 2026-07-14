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
//   • The time-of-day suggestion banner appears at the top of the list
//     when grouping is active. It is dismissible and resets on cold launch.

import SwiftUI
import ComposableArchitecture

// MARK: - Energy Suggestion Banner

struct EnergySuggestionBanner: View {
    let suggestedLevel: EnergyLevel
    let hour: Int
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: suggestedLevel.icon)
                .font(.title3)
                .foregroundStyle(suggestedLevel.color)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                (Text(suggestedLevel.displayName)
                    .foregroundStyle(suggestedLevel.color)
                + Text(String(localized: " · suggested now"))
                    .foregroundStyle(.secondary))
                    .font(.subheadline.weight(.semibold))

                Text(EnergySuggestion.suggestionReason(forHour: hour))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)

            Button {
                withAnimation(.easeOut(duration: 0.2)) {
                    onDismiss()
                }
                HapticManager.impact(.light)
            } label: {
                Image(systemName: "xmark")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(6)
                    .background(.quaternary, in: Circle())
                    .frame(minWidth: 44, minHeight: 44)  // HIG 44pt minimum (issue #90)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(String(localized: "Dismiss energy suggestion"))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(suggestedLevel.color.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(suggestedLevel.color.opacity(0.22), lineWidth: 1)
                )
        )
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .transition(.asymmetric(
            insertion: .move(edge: .top).combined(with: .opacity),
            removal: .opacity
        ))
    }
}

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

    // Sections order: deep first (highest cognitive demand), then shallow, then admin
    private let sectionOrder: [EnergyLevel] = [.deep, .shallow, .admin]

    private var currentHour: Int {
        Calendar.current.component(.hour, from: currentDate)
    }

    private var suggestedLevel: EnergyLevel {
        EnergySuggestion.suggestedLevel(forHour: currentHour)
    }

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
            // Suggestion banner as a List item so it scrolls with content
            if !store.energySuggestionDismissed {
                EnergySuggestionBanner(
                    suggestedLevel: suggestedLevel,
                    hour: currentHour,
                    onDismiss: { store.send(.energySuggestionDismissed) }
                )
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }

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
        .animation(.smooth(duration: 0.2), value: store.energySuggestionDismissed)
        .refreshable { store.send(.refresh) }
    }
}
