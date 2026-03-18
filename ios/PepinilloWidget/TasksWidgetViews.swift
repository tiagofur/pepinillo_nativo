// TasksWidgetViews.swift
// Pepinillo — Deep Work Companion for Apple
//
// Views for the Tasks home screen widget.
// Design follows the Android Wear task list pattern:
//   - Linked task gets a prominent accent-colored chip at the top with "En progreso" label
//   - Other tasks show as secondary rows with energy emoji + pomodoro progress
// Small: task count + next task. Medium: top 3-4 tasks. Large: full list with completion toggles.

import SwiftUI
import WidgetKit

// MARK: - Energy Emoji Helper

private func energyEmoji(for icon: String) -> String {
    switch icon {
    case "brain.head.profile": return "🔥"   // Deep work
    case "tray":               return "⚡"    // Shallow
    case "folder":             return "💧"    // Admin
    default:                   return "⚡"
    }
}

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
                                Text(energyEmoji(for: first.energyIcon))
                                    .font(.caption2)
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

    /// Linked task shown separately at top, remaining tasks fill below
    private var linkedTask: TasksWidgetEntry.WidgetTask? {
        guard let activeID = entry.activeTaskID else { return nil }
        return entry.tasks.first { $0.id == activeID }
    }

    private var otherTasks: [TasksWidgetEntry.WidgetTask] {
        let activeID = entry.activeTaskID
        return entry.tasks.filter { $0.id != activeID }
    }

    private var maxOtherRows: Int {
        linkedTask != nil ? 2 : 4
    }

    var body: some View {
        ZStack {
            if showsBackground {
                ContainerRelativeShape()
                    .fill(Color(.systemBackground))
            }

            if showsBackground {
                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Image(systemName: "checklist")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(String(localized: "Tasks (\(entry.tasks.count))"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
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
                        // Linked task chip (Wear-style primary chip)
                        if let linked = linkedTask {
                            LinkedTaskChip(task: linked)
                        }

                        // Other tasks
                        ForEach(Array(otherTasks.prefix(maxOtherRows))) { task in
                            TaskRowCompact(task: task)
                        }

                        let remaining = otherTasks.count - maxOtherRows
                        if remaining > 0 {
                            Text(String(localized: "+\(remaining) more"))
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

    private var linkedTask: TasksWidgetEntry.WidgetTask? {
        guard let activeID = entry.activeTaskID else { return nil }
        return entry.tasks.first { $0.id == activeID }
    }

    private var otherTasks: [TasksWidgetEntry.WidgetTask] {
        let activeID = entry.activeTaskID
        return entry.tasks.filter { $0.id != activeID }
    }

    private var maxOtherRows: Int {
        linkedTask != nil ? 5 : 7
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
                    Text(String(localized: "Tasks (\(entry.tasks.count))"))
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
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
                    // Linked task chip (Wear-style primary chip)
                    if let linked = linkedTask {
                        LinkedTaskChip(task: linked)
                    }

                    // Other tasks with interactive completion
                    ForEach(Array(otherTasks.prefix(maxOtherRows))) { task in
                        TaskRowInteractive(task: task)
                    }

                    let remaining = otherTasks.count - maxOtherRows
                    if remaining > 0 {
                        Text(String(localized: "+\(remaining) more"))
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

// MARK: - Linked Task Chip (Wear-style primary chip)

private struct LinkedTaskChip: View {
    let task: TasksWidgetEntry.WidgetTask

    var body: some View {
        HStack(spacing: 8) {
            Text("▶")
                .font(.caption)

            VStack(alignment: .leading, spacing: 1) {
                Text(task.title)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Text("🍅")
                        .font(.caption2)
                    Text(String(localized: "In progress"))
                        .font(.caption2)
                    if task.estimatedPomodoros > 0 {
                        Text("· \(task.completedPomodoros)/\(task.estimatedPomodoros)")
                            .font(.caption2)
                            .monospacedDigit()
                    }
                }
                .opacity(0.85)
            }

            Spacer(minLength: 0)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.accentColor)
        )
    }
}

// MARK: - Task Row Components

private struct TaskRowCompact: View {
    let task: TasksWidgetEntry.WidgetTask

    var body: some View {
        HStack(spacing: 6) {
            Text(energyEmoji(for: task.energyIcon))
                .font(.caption2)
                .frame(width: 16)

            Text(task.title)
                .font(.caption)
                .lineLimit(1)

            Spacer(minLength: 4)

            // Pomodoro progress
            if task.estimatedPomodoros > 0 {
                Text("🍅 \(task.completedPomodoros)/\(task.estimatedPomodoros)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        .padding(.vertical, 2)
    }
}

private struct TaskRowInteractive: View {
    let task: TasksWidgetEntry.WidgetTask

    var body: some View {
        HStack(spacing: 8) {
            // Completion toggle
            Button(intent: CompleteTaskFromWidgetIntent(taskID: task.id)) {
                Image(systemName: "circle")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)

            // Energy emoji
            Text(energyEmoji(for: task.energyIcon))
                .font(.caption)
                .frame(width: 18)

            // Title
            Text(task.title)
                .font(.subheadline)
                .lineLimit(1)

            Spacer(minLength: 4)

            // Pomodoro progress
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
        }
        .padding(.vertical, 3)
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
