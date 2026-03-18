// TasksWidgetViews.swift
// Pepinillo — Deep Work Companion for Apple
//
// Views for the Tasks home screen widget.
// Small: task count + next task. Medium: top 3-4 tasks. Large: full list with completion toggles.

import SwiftUI
import WidgetKit

// MARK: - Small Widget

struct TasksWidgetSmall: View {
    let entry: TasksWidgetEntry
    @Environment(\.showsWidgetContainerBackground) var showsBackground

    var body: some View {
        ZStack {
            if showsBackground {
                ContainerRelativeShape()
                    .fill(Color(.systemBackground))
            }

            if showsBackground {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "checklist")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(String(localized: "Tasks"))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }

                    Spacer()

                    if entry.tasks.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Image(systemName: "checkmark.circle")
                                .font(.title2)
                                .foregroundStyle(.green)
                            Text(String(localized: "All done!"))
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text(String(localized: "No pending tasks"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        // Task count
                        Text("\(entry.tasks.count)")
                            .font(.system(.largeTitle, design: .rounded, weight: .bold))

                        Text(entry.tasks.count == 1
                             ? String(localized: "active task")
                             : String(localized: "active tasks"))
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        // Next task preview
                        if let first = entry.tasks.first {
                            HStack(spacing: 4) {
                                Image(systemName: first.energyIcon)
                                    .font(.caption2)
                                    .foregroundStyle(.accentColor)
                                Text(first.title)
                                    .font(.caption)
                                    .lineLimit(1)
                            }
                        }
                    }
                }
                .padding(12)
            } else {
                // StandBy mode
                VStack(spacing: 8) {
                    Text("\(entry.tasks.count)")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                    Text(String(localized: "tasks"))
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Medium Widget

struct TasksWidgetMedium: View {
    let entry: TasksWidgetEntry
    @Environment(\.showsWidgetContainerBackground) var showsBackground

    private var visibleTasks: [TasksWidgetEntry.WidgetTask] {
        Array(entry.tasks.prefix(4))
    }

    var body: some View {
        ZStack {
            if showsBackground {
                ContainerRelativeShape()
                    .fill(Color(.systemBackground))
            }

            if showsBackground {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Image(systemName: "checklist")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(String(localized: "Tasks"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(entry.tasks.count)")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                    }

                    if entry.tasks.isEmpty {
                        Spacer()
                        HStack {
                            Spacer()
                            VStack(spacing: 6) {
                                Image(systemName: "checkmark.circle")
                                    .font(.title)
                                    .foregroundStyle(.green)
                                Text(String(localized: "All done!"))
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                            Spacer()
                        }
                        Spacer()
                    } else {
                        ForEach(visibleTasks) { task in
                            TaskRowCompact(
                                task: task,
                                isLinked: task.id == entry.activeTaskID
                            )
                        }

                        if entry.tasks.count > 4 {
                            Text(String(localized: "+\(entry.tasks.count - 4) more"))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(14)
            } else {
                // StandBy mode
                VStack(alignment: .leading, spacing: 8) {
                    if let first = entry.tasks.first {
                        Text(first.title)
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)
                            .lineLimit(2)
                    }
                    Text(String(localized: "\(entry.tasks.count) tasks pending"))
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .padding()
            }
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Large Widget

struct TasksWidgetLarge: View {
    let entry: TasksWidgetEntry
    @Environment(\.showsWidgetContainerBackground) var showsBackground

    private var visibleTasks: [TasksWidgetEntry.WidgetTask] {
        Array(entry.tasks.prefix(7))
    }

    var body: some View {
        ZStack {
            if showsBackground {
                ContainerRelativeShape()
                    .fill(Color(.systemBackground))
            }

            VStack(alignment: .leading, spacing: 8) {
                // Header
                HStack {
                    Image(systemName: "checklist")
                        .foregroundStyle(.secondary)
                    Text(String(localized: "Tasks"))
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                    Text(String(localized: "\(entry.tasks.count) active"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if entry.tasks.isEmpty {
                    Spacer()
                    HStack {
                        Spacer()
                        VStack(spacing: 8) {
                            Image(systemName: "checkmark.circle")
                                .font(.largeTitle)
                                .foregroundStyle(.green)
                            Text(String(localized: "All done!"))
                                .font(.headline)
                            Text(String(localized: "No pending tasks"))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    Spacer()
                } else {
                    ForEach(visibleTasks) { task in
                        TaskRowInteractive(
                            task: task,
                            isLinked: task.id == entry.activeTaskID
                        )
                    }

                    if entry.tasks.count > 7 {
                        Text(String(localized: "+\(entry.tasks.count - 7) more"))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 0)

                    // Start focus button
                    if !AppGroupDefaults.isSessionActive {
                        Button(intent: StartFocusFromWidgetIntent()) {
                            Label(String(localized: "Start Focus"), systemImage: "play.fill")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                        }
                        .tint(.accentColor)
                    }
                }
            }
            .padding(16)
        }
    }
}

// MARK: - Task Row Components

private struct TaskRowCompact: View {
    let task: TasksWidgetEntry.WidgetTask
    let isLinked: Bool

    var body: some View {
        HStack(spacing: 6) {
            // Energy icon
            Image(systemName: task.energyIcon)
                .font(.caption2)
                .foregroundStyle(isLinked ? .accentColor : .secondary)
                .frame(width: 14)

            // Title
            Text(task.title)
                .font(.caption)
                .fontWeight(isLinked ? .semibold : .regular)
                .foregroundStyle(isLinked ? .primary : .primary)
                .lineLimit(1)

            Spacer(minLength: 4)

            // Pomodoro progress
            if task.estimatedPomodoros > 0 {
                Text("\(task.completedPomodoros)/\(task.estimatedPomodoros)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            // Linked indicator
            if isLinked {
                Image(systemName: "timer")
                    .font(.caption2)
                    .foregroundStyle(.accentColor)
            }
        }
        .padding(.vertical, 2)
        .padding(.horizontal, isLinked ? 6 : 0)
        .background(
            isLinked
                ? RoundedRectangle(cornerRadius: 6)
                    .fill(Color.accentColor.opacity(0.1))
                : nil
        )
    }
}

private struct TaskRowInteractive: View {
    let task: TasksWidgetEntry.WidgetTask
    let isLinked: Bool

    var body: some View {
        HStack(spacing: 8) {
            // Completion toggle
            Button(intent: CompleteTaskFromWidgetIntent(taskID: task.id)) {
                Image(systemName: "circle")
                    .font(.body)
                    .foregroundStyle(isLinked ? .accentColor : .secondary)
            }
            .buttonStyle(.plain)

            // Energy icon
            Image(systemName: task.energyIcon)
                .font(.caption)
                .foregroundStyle(isLinked ? .accentColor : .secondary)
                .frame(width: 16)

            // Title
            Text(task.title)
                .font(.subheadline)
                .fontWeight(isLinked ? .semibold : .regular)
                .lineLimit(1)

            Spacer(minLength: 4)

            // Pomodoro progress bar
            if task.estimatedPomodoros > 0 {
                HStack(spacing: 2) {
                    PomodoroProgressDots(
                        completed: task.completedPomodoros,
                        total: task.estimatedPomodoros
                    )
                    Text("\(task.completedPomodoros)/\(task.estimatedPomodoros)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }

            // Linked / focus start
            if isLinked {
                Image(systemName: "timer")
                    .font(.caption)
                    .foregroundStyle(.accentColor)
            }
        }
        .padding(.vertical, 3)
        .padding(.horizontal, isLinked ? 8 : 0)
        .background(
            isLinked
                ? RoundedRectangle(cornerRadius: 8)
                    .fill(Color.accentColor.opacity(0.08))
                : nil
        )
    }
}

// MARK: - Pomodoro Progress Dots

private struct PomodoroProgressDots: View {
    let completed: Int
    let total: Int

    private var displayTotal: Int { min(total, 6) }

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<displayTotal, id: \.self) { i in
                Circle()
                    .fill(i < completed ? ModeColors.pomodoro : ModeColors.pomodoro.opacity(0.2))
                    .frame(width: 4, height: 4)
            }
        }
    }
}
