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

struct TasksWidgetLockedView: View {
    var body: some View {
        VStack(spacing: 7) {
            Image(systemName: "lock.fill")
                .font(.title2)
                .foregroundStyle(Color.accentColor)
            Text(String(localized: "Pepinillo+"))
                .font(.headline)
            Text(String(localized: LocalizedStringResource(
                "widget.tasks.locked.message",
                defaultValue: "Open Pepinillo to unlock the Tasks widget."
            )))
            .font(.caption)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Small Widget

struct TasksWidgetSmall: View {
    let entry: TasksWidgetEntry
    @Environment(\.showsWidgetContainerBackground) var showsBackground

    var body: some View {
        Group {
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
                        if entry.isSessionActive {
                            Image(systemName: "timer")
                                .font(.caption2)
                                .foregroundStyle(Color.accentColor)
                        }
                    }

                    Spacer(minLength: 4)

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
                        Text("\(entry.tasks.count)")
                            .font(.system(.largeTitle, design: .rounded, weight: .bold))

                        Text(entry.tasks.count == 1
                             ? String(localized: "active task")
                             : String(localized: "active tasks"))
                            .font(.caption)
                            .foregroundStyle(.secondary)

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
                .padding(0)
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
        Group {
            if showsBackground {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: "checklist")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(String(localized: "Tasks (\(entry.tasks.count))"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        if !entry.isSessionActive, !entry.tasks.isEmpty {
                            Button(intent: StartFocusFromTasksWidgetIntent()) {
                                Image(systemName: "play.fill")
                                    .font(.caption2)
                            }
                            .buttonStyle(.plain)
                            .tint(.accentColor)
                        }
                    }

                    if entry.tasks.isEmpty {
                        Spacer(minLength: 4)
                        HStack {
                            Spacer()
                            VStack(spacing: 5) {
                                Image(systemName: "checkmark.circle")
                                    .font(.title2)
                                    .foregroundStyle(.green)
                                Text(String(localized: "All done!"))
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                            Spacer()
                        }
                        Spacer(minLength: 4)
                    } else {
                        if let linked = linkedTask {
                            LinkedTaskChip(task: linked)
                        }

                        ForEach(Array(otherTasks.prefix(maxOtherRows))) { task in
                            TaskRowCompact(task: task, canStartFocus: !entry.isSessionActive)
                        }

                        let remaining = otherTasks.count - maxOtherRows
                        if remaining > 0 {
                            Text(String(localized: "+\(remaining) more"))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(0)
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
                .padding(0)
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
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "checklist")
                        .foregroundStyle(.secondary)
                    Text(String(localized: "Tasks (\(entry.tasks.count))"))
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                Spacer()
                if entry.isSessionActive {
                    Label(String(localized: "Running"), systemImage: "timer")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.accentColor)
                }
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
                if let linked = linkedTask {
                    LinkedTaskChip(task: linked)
                }

                ForEach(Array(otherTasks.prefix(maxOtherRows))) { task in
                    TaskRowInteractive(task: task, canStartFocus: !entry.isSessionActive)
                }

                let remaining = otherTasks.count - maxOtherRows
                if remaining > 0 {
                    Text(String(localized: "+\(remaining) more"))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                if !entry.isSessionActive {
                    Button(intent: StartFocusFromTasksWidgetIntent()) {
                        Label(String(localized: "Start Focus"), systemImage: "play.fill")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                    }
                    .tint(.accentColor)
                }
            }
        }
        .padding(0)
    }
}

// MARK: - Linked Task Chip (Wear-style primary chip)

private struct LinkedTaskChip: View {
    let task: TasksWidgetEntry.WidgetTask

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "timer")
                .font(.caption)
                .foregroundStyle(.white)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 1) {
                Text(task.title)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Text(String(localized: "In progress"))
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                    if task.estimatedPomodoros > 0 {
                        Text("· \(task.completedPomodoros)/\(task.estimatedPomodoros)")
                            .font(.caption2)
                            .foregroundStyle(.white)
                            .monospacedDigit()
                    }
                }
                .opacity(0.85)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Task Row Components

private struct TaskRowCompact: View {
    let task: TasksWidgetEntry.WidgetTask
    let canStartFocus: Bool

    var body: some View {
        HStack(spacing: 6) {
            if canStartFocus {
                Button(intent: StartFocusWithTaskIntent(taskID: task.id)) {
                    Image(systemName: "play.fill")
                        .font(.caption2)
                }
                .buttonStyle(.plain)
                .tint(.accentColor)
            }

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
    let canStartFocus: Bool

    var body: some View {
        HStack(spacing: 8) {
            // Completion toggle. A pending completion command (not yet consumed
            // by the app, S7) renders as completed immediately for feedback.
            let isPendingCompletion = AppGroupDefaults.externalCompleteTaskRequested
                && AppGroupDefaults.externalCompleteTaskID == task.id
            Button(intent: CompleteTaskFromWidgetIntent(taskID: task.id)) {
                Image(systemName: isPendingCompletion ? "checkmark.circle.fill" : "circle")
                    .font(.body)
                    .foregroundStyle(isPendingCompletion ? .green : .secondary)
            }
            .buttonStyle(.plain)
            .disabled(isPendingCompletion)

            // Energy emoji
            Text(energyEmoji(for: task.energyIcon))
                .font(.caption)
                .frame(width: 18)

            // Title
            Text(task.title)
                .font(.subheadline)
                .lineLimit(1)

            Spacer(minLength: 4)

            if canStartFocus {
                Button(intent: StartFocusWithTaskIntent(taskID: task.id)) {
                    Image(systemName: "play.fill")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .tint(.accentColor)
            }

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
    @Environment(\.widgetRenderingMode) var renderingMode

    private var displayTotal: Int { min(total, 6) }

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<displayTotal, id: \.self) { i in
                let dotColor: Color = renderingMode == .accented ? .primary : ModeColors.pomodoro
                Circle()
                    .fill(i < completed ? dotColor : dotColor.opacity(0.2))
                    .frame(width: 4, height: 4)
            }
        }
    }
}
