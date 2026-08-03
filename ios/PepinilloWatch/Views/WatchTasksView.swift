// WatchTasksView.swift
// Pepinillo — Deep Work Companion for Apple
//
// Apple Watch tasks screen. Shows today's tasks synced from iOS.
// Tap to toggle completion, long press to link/unlink a task to the timer.

import SwiftUI
import ComposableArchitecture
import WatchKit

// MARK: - WatchTasksView

struct WatchTasksView: View {
    @Bindable var store: StoreOf<WatchTasksFeature>
    let linkedTaskID: UUID?

    var body: some View {
        Group {
            if store.tasks.isEmpty {
                emptyState
            } else {
                taskList
            }
        }
    }

    // MARK: - Task List

    private var taskList: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Header
                HStack {
                    Image(systemName: "checklist")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    Text(String(localized: "Today"))
                        .font(.system(size: 13, weight: .semibold))
                    Spacer()
                    let completed = store.tasks.filter(\.isCompleted).count
                    Text("\(completed)/\(store.tasks.count)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 6)

                // Tasks
                ForEach(sortedTasks) { task in
                    WatchTaskRow(
                        task: task,
                        isLinked: linkedTaskID == task.id,
                        onTap: { store.send(.taskTapped(task.id)) },
                        onLongPress: { store.send(.taskLongPressed(task.id)) }
                    )
                }
            }
            .padding(.top, 4)
        }
    }

    private var sortedTasks: [WatchTaskItem] {
        // Active tasks first (uncompleted), then completed
        store.tasks.sorted { lhs, rhs in
            if lhs.isCompleted != rhs.isCompleted {
                return !lhs.isCompleted
            }
            // Higher priority first
            return lhs.priority > rhs.priority
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "checklist")
                .font(.system(size: 28))
                .foregroundStyle(.tertiary)
            Text(String(localized: "No tasks today"))
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
            Text(String(localized: "Add tasks on iPhone"))
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - WatchTaskRow

private struct WatchTaskRow: View {
    let task: WatchTaskItem
    let isLinked: Bool
    let onTap: () -> Void
    let onLongPress: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                // Completion indicator
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 16))
                    .foregroundStyle(task.isCompleted ? .green : .secondary)
                    .frame(width: 24, height: 24)

                // Task info
                VStack(alignment: .leading, spacing: 1) {
                    Text(task.title)
                        .font(.system(size: 13, weight: isLinked ? .semibold : .regular))
                        .foregroundStyle(task.isCompleted ? .secondary : .primary)
                        .strikethrough(task.isCompleted)
                        .lineLimit(2)

                    HStack(spacing: 4) {
                        // Priority indicator
                        if task.priority >= 3 {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 8))
                                .foregroundStyle(.red)
                        } else if task.priority >= 2 {
                            Image(systemName: "exclamationmark")
                                .font(.system(size: 8))
                                .foregroundStyle(.orange)
                        }

                        // Pomodoro progress
                        if task.estimatedPomodoros > 0 {
                            HStack(spacing: 2) {
                                Image(systemName: "timer")
                                    .font(.system(size: 8))
                                    .foregroundStyle(ModeColors.pomodoro)
                                Text("\(task.completedPomodoros)/\(task.estimatedPomodoros)")
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Spacer(minLength: 0)

                // Link indicator
                if isLinked {
                    Image(systemName: "link.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(ModeColors.pomodoro)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
            .pepinilloGlass(
                cornerRadius: 12,
                tint: isLinked ? ModeColors.pomodoro : nil,
                tintOpacity: isLinked ? 0.16 : 0.06
            )
            .padding(.vertical, 2)
        }
        .buttonStyle(.plain)
        .onLongPressGesture {
            WKInterfaceDevice.current().play(.click)
            onLongPress()
        }
    }
}
