// WatchTasksView.swift
// Pepinillo — Deep Work Companion for Apple
//
// Apple Watch tasks screen. Shows today's tasks synced from iOS.
// Tap a row to toggle completion; tap the trailing link control to
// focus/unlink that task on the timer (#882).

import SwiftUI
import ComposableArchitecture

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
                        onLinkToggle: { store.send(.taskLongPressed(task.id)) }
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
    let onLinkToggle: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            // Tap-to-complete area (a Button here would swallow held presses —
            // see #882 QA history; a discrete tap gesture keeps the row calm).
            mainContent
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture(perform: onTap)
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isButton)

            // #882 (pivot after live QA): held presses never engage a context
            // menu inside the verticalPage+ScrollView hierarchy — two gesture
            // attempts failed — so the link affordance must be explicit.
            // Compact width so the title keeps the room (QA: the 44pt-wide
            // control squeezed titles); the vertical hit target stays 44.
            if !task.isCompleted {
                Button(action: onLinkToggle) {
                    Image(systemName: isLinked ? "link.circle.fill" : "link")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(isLinked ? ModeColors.pomodoro : Color.secondary)
                        .frame(width: 30, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(
                    isLinked
                        ? String(localized: "Unlink Task")
                        : String(localized: "Focus on task")
                )
            } else if isLinked {
                // Completed rows keep the (non-interactive) link indicator.
                Image(systemName: "link.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(ModeColors.pomodoro)
                    .frame(width: 30, height: 44)
            }
        }
        .padding(.horizontal, 2)
        .padding(.vertical, 2)
        .background(
            isLinked
                ? AnyShapeStyle(ModeColors.pomodoro.opacity(0.12))
                : AnyShapeStyle(Color.clear)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var mainContent: some View {
        HStack(spacing: 6) {
            // Completion indicator
            Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 14))
                .foregroundStyle(task.isCompleted ? .green : .secondary)
                .frame(width: 19, height: 19)

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
                            Text("🍅")
                                .font(.system(size: 8))
                            Text("\(task.completedPomodoros)/\(task.estimatedPomodoros)")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.leading, 3)
        .padding(.trailing, 0)
        .padding(.vertical, 6)
    }
}
