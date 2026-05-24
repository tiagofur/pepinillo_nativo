// TaskRow.swift
// Pepinillo — Deep Work Companion for Apple
//
// Reusable task row used in PlanTaskList and any other task list surfaces.

import SwiftUI
import ComposableArchitecture

// MARK: - Task Row

struct TaskRow: View {
    let task: TaskListFeature.TaskItemState
    let onTap: () -> Void
    let onComplete: () -> Void
    let onStartFocus: () -> Void
    var onScheduledForTodayToggled: (() -> Void)?
    var onEnergyChanged: ((EnergyLevel) -> Void)?
    var onRecurrenceChanged: ((String?) -> Void)?

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                completionButton
                taskInfo
                Spacer()
                if !task.isCompleted {
                    focusButton
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(cardBackground, in: RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(cardBorderColor, lineWidth: 1)
            )
            .shadow(
                color: cardShadowColor,
                radius: cardShadowRadius,
                x: 0,
                y: cardShadowOffsetY
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            // Energy level
            Menu {
                ForEach(EnergyLevel.allCases, id: \.self) { level in
                    Button {
                        onEnergyChanged?(level)
                    } label: {
                        Label(level.displayName, systemImage: level.icon)
                    }
                }
            } label: {
                Label(String(localized: "Energy Level"), systemImage: "bolt")
            }

            // Today scheduling
            Button {
                onScheduledForTodayToggled?()
            } label: {
                Label(
                    task.scheduledForToday
                        ? String(localized: "Remove from Today")
                        : String(localized: "Add to Today"),
                    systemImage: task.scheduledForToday ? "minus.circle" : "bolt.circle.fill"
                )
            }

            // Recurrence
            Menu {
                ForEach(RecurrencePreset.allCases, id: \.self) { preset in
                    Button {
                        onRecurrenceChanged?(preset.rawValue)
                    } label: {
                        Label(preset.displayName, systemImage: preset.icon)
                    }
                }
                if task.recurrenceRule != nil {
                    Divider()
                    Button(role: .destructive) {
                        onRecurrenceChanged?(nil)
                    } label: {
                        Label(String(localized: "Remove Recurrence"), systemImage: "xmark")
                    }
                }
            } label: {
                Label(String(localized: "Repeat"), systemImage: "arrow.clockwise")
            }

            Divider()

            Button {
                onStartFocus()
            } label: {
                Label(String(localized: "Start Focus"), systemImage: "play.circle")
            }
            .disabled(task.isCompleted)
        }
    }

    // MARK: - Row Subviews

    private var completionButton: some View {
        Button(action: {
            onComplete()
            HapticManager.notification(.success)
        }) {
            Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundStyle(checkboxColor)
                .contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(task.isCompleted
            ? String(localized: "Mark as incomplete")
            : String(localized: "Mark as complete"))
    }

    private var taskInfo: some View {
        VStack(alignment: .leading, spacing: 3) {
            taskTitleView
                .strikethrough(task.isCompleted)
                .foregroundStyle(task.isCompleted ? .secondary : .primary)
                .lineLimit(2)

            // Notes snippet
            if let notes = task.notes, !notes.isEmpty {
                Text(notes)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            // Metadata badges
            metadataBadges
        }
    }

    @ViewBuilder
    private var metadataBadges: some View {
        let hasBadges = task.dueDate != nil || task.scheduledForToday
            || task.estimatedPomodoros > 0 || task.subtaskProgress.total > 0
            || task.recurrenceRule != nil

        if hasBadges {
            HStack(spacing: 6) {
                // Due date
                if let due = task.dueDate {
                    let isOverdue = due < Calendar.current.startOfDay(for: .now) && !task.isCompleted
                    Label(formatDueDate(due), systemImage: "calendar")
                        .font(.caption2)
                        .foregroundStyle(isOverdue ? .red : .secondary)
                }

                // Today indicator
                if task.scheduledForToday && task.dueDate == nil {
                    Label(String(localized: "Today"), systemImage: "bolt.fill")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }

                // Energy level
                Label(task.energyLevel.displayName, systemImage: task.energyLevel.icon)
                    .font(.caption2)
                    .foregroundStyle(task.energyLevel.color)

                // Pomodoros
                if task.estimatedPomodoros > 0 {
                    Text("🍅 \(task.completedPomodoros)/\(task.estimatedPomodoros)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                // Subtasks
                if task.subtaskProgress.total > 0 {
                    Text("☑ \(task.subtaskProgress.completed)/\(task.subtaskProgress.total)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                // Recurrence
                if let rule = task.recurrenceRule,
                   let preset = RecurrencePreset.from(rule: rule) {
                    Label(preset.displayName, systemImage: preset.icon)
                        .font(.caption2)
                        .foregroundStyle(.teal)
                }
            }
        }
    }

    private var focusButton: some View {
        Button(action: onStartFocus) {
            Image(systemName: "play.circle")
                .font(.title3)
                .foregroundStyle(.tint)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(String(localized: "Start focus session with this task"))
    }

    // MARK: - Helpers

    private var isOverdue: Bool {
        guard !task.isCompleted, let due = task.dueDate else { return false }
        return due < Calendar.current.startOfDay(for: .now)
    }

    private var isDueToday: Bool {
        guard !task.isCompleted, let due = task.dueDate else { return false }
        return Calendar.current.isDateInToday(due)
    }

    private var cardBackground: Color {
        if task.isCompleted {
            return Color(uiColor: .secondarySystemGroupedBackground)
        } else if isOverdue {
            return Color.red.opacity(0.05)
        } else if isDueToday {
            return Color.orange.opacity(0.05)
        } else {
            return Color(uiColor: .secondarySystemGroupedBackground)
        }
    }

    private var cardBorderColor: Color {
        if task.isCompleted {
            return Color(uiColor: .separator).opacity(0.15)
        } else if isOverdue {
            return Color.red.opacity(0.3)
        } else if isDueToday {
            return Color.orange.opacity(0.3)
        } else {
            return Color(uiColor: .separator).opacity(0.3)
        }
    }

    private var cardShadowColor: Color {
        if task.isCompleted {
            return Color.black.opacity(0.01)
        } else {
            return Color.black.opacity(0.05)
        }
    }

    private var cardShadowRadius: CGFloat {
        task.isCompleted ? 1 : 5
    }

    private var cardShadowOffsetY: CGFloat {
        task.isCompleted ? 0.5 : 2
    }

    private var checkboxColor: Color {
        if task.isCompleted {
            return .green
        }
        switch task.priority {
        case .high:
            return .red
        case .medium:
            return .orange
        case .low:
            return .blue
        case .none:
            return .secondary
        }
    }

    private func priorityPrefix(for priority: TaskPriority) -> String {
        switch priority {
        case .high:
            return "!!! "
        case .medium:
            return "!! "
        case .low:
            return "! "
        case .none:
            return ""
        }
    }

    private var taskTitleView: Text {
        let prefix = priorityPrefix(for: task.priority)
        if !prefix.isEmpty {
            let prefixColor = task.isCompleted ? Color.secondary : (priorityColor(for: task.priority, isCompleted: false) ?? .primary)
            return Text(prefix)
                .font(.body.weight(.bold))
                .foregroundStyle(prefixColor)
            + Text(task.title)
        } else {
            return Text(task.title)
        }
    }

    private func priorityColor(for priority: TaskPriority, isCompleted: Bool) -> Color? {
        guard !isCompleted else { return nil }
        switch priority {
        case .high:
            return .red
        case .medium:
            return .orange
        case .low:
            return .blue
        case .none:
            return nil
        }
    }

    private func formatDueDate(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return String(localized: "Today") }
        if calendar.isDateInTomorrow(date) { return String(localized: "Tomorrow") }
        if calendar.isDateInYesterday(date) { return String(localized: "Yesterday") }
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}
