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
            HStack(spacing: 0) {
                if let pColor = priorityColor(for: task.priority, isCompleted: task.isCompleted) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(pColor)
                        .frame(width: 4, height: 36)
                        .padding(.leading, 12)
                }
                
                HStack(spacing: 12) {
                    completionButton
                    taskInfo
                    Spacer()
                    if !task.isCompleted {
                        focusButton
                    }
                }
                .padding(.leading, priorityColor(for: task.priority, isCompleted: task.isCompleted) != nil ? 8 : 16)
                .padding(.trailing, 16)
                .padding(.vertical, 12)
            }
            .background(cardBackground(isCompleted: task.isCompleted), in: RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(cardBorderColor(isCompleted: task.isCompleted), lineWidth: 1)
            )
            .shadow(
                color: Color.black.opacity(task.isCompleted ? 0.01 : 0.03),
                radius: task.isCompleted ? 1 : 3,
                x: 0,
                y: task.isCompleted ? 0.5 : 1.5
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
                .foregroundStyle(task.isCompleted ? .green : .secondary)
                .contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(task.isCompleted
            ? String(localized: "Mark as incomplete")
            : String(localized: "Mark as complete"))
    }

    private var taskInfo: some View {
        VStack(alignment: .leading, spacing: 3) {
            // Title
            HStack(spacing: 4) {
                if task.priority == .high {
                    Image(systemName: "exclamationmark")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.red)
                        .contentTransition(.symbolEffect(.replace))
                        .accessibilityLabel(String(localized: "High priority"))
                } else if task.priority == .medium {
                    Image(systemName: "arrow.up")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                        .contentTransition(.symbolEffect(.replace))
                        .accessibilityLabel(String(localized: "Medium priority"))
                }
                Text(task.title)
                    .strikethrough(task.isCompleted)
                    .foregroundStyle(task.isCompleted ? .secondary : .primary)
                    .lineLimit(2)
            }

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

    private func cardBackground(isCompleted: Bool) -> Color {
        Color(uiColor: .secondarySystemGroupedBackground)
    }

    private func cardBorderColor(isCompleted: Bool) -> Color {
        if isCompleted {
            return Color(uiColor: .separator).opacity(0.15)
        } else {
            return Color(uiColor: .separator).opacity(0.3)
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
