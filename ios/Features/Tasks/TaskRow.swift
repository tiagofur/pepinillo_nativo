// TaskRow.swift
// Pepinillo — Deep Work Companion for Apple
//
// Reusable task row used in PlanTaskList and any other task list surfaces.

import SwiftUI
import ComposableArchitecture

// MARK: - Task Row

struct TaskRow: View, Equatable {
    let task: TaskListFeature.TaskItemState
    let onTap: () -> Void
    let onComplete: () -> Void
    let onStartFocus: () -> Void
    var onScheduledForTodayToggled: (() -> Void)?
    var onEnergyChanged: ((EnergyLevel) -> Void)?
    var onRecurrenceChanged: ((String?) -> Void)?

    // Equatable by visual state only (issue #81). Closures are intentionally
    // ignored: they change identity on every parent re-render but do not affect
    // what the row draws, so skipping the re-render when `task` is unchanged is
    // correct and avoids re-running chipData/Calendar math per row.
    nonisolated static func == (lhs: TaskRow, rhs: TaskRow) -> Bool {
        lhs.task == rhs.task
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 0) {
                // Priority color bar — calm leading indicator replacing text prefixes
                priorityBar

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
            }
            .background(cardBackgroundTint)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
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
                    .frame(minWidth: 44, minHeight: 44)  // HIG 44pt minimum (issue #90)
                    .contentShape(Rectangle())
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
                .frame(minWidth: 44, minHeight: 44)  // HIG 44pt minimum (issue #90)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(task.isCompleted
            ? String(localized: "Mark as incomplete")
            : String(localized: "Mark as complete"))
    }

    private var taskInfo: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(task.title)
                .font(.body)
                .strikethrough(task.isCompleted)
                .foregroundStyle(task.isCompleted ? .secondary : .primary)
                .lineLimit(1)

            // Metadata chip (single — see chip priority logic)
            metadataChip
        }
    }

    /// Single metadata chip — chip priority:
    ///   1. Energy level (app's most distinctive concept)
    ///   2. Due-today / overdue indicator
    ///   3. Recurring icon
    ///   4. Nothing (no chip)
    @ViewBuilder
    private var metadataChip: some View {
        // 1. Energy level if set (non-default detection: always show — energy is core)
        let chipContent = chipData
        if let (label, icon, color) = chipContent {
            Label(label, systemImage: icon)
                .font(.caption2)
                .foregroundStyle(color)
                .lineLimit(1)
        }
    }

    /// Returns (label, icon, color) for the single metadata chip, or nil.
    private var chipData: (String, String, Color)? {
        // 1. Energy level (always the primary differentiator)
        let energy = task.energyLevel
        // Show energy chip always (all tasks have an energy level)
        let energyChip: (String, String, Color) = (energy.displayName, energy.icon, energy.color)

        // 2. Due date — overrides energy when task is overdue or due today
        if let due = task.dueDate {
            let cal = Calendar.current
            let isOverdue = due < cal.startOfDay(for: .now) && !task.isCompleted
            let isToday = cal.isDateInToday(due) && !task.isCompleted
            if isOverdue {
                return (String(localized: "Overdue"), "calendar", .red)
            }
            if isToday {
                return (String(localized: "Due today"), "calendar", .orange)
            }
        }

        // 3. If due date exists but not urgent, still show energy
        if task.dueDate == nil {
            // Due-today via scheduledForToday toggle (no explicit date)
            if task.scheduledForToday {
                return (String(localized: "Today"), "bolt.fill", .green)
            }
            // Recurring
            if let rule = task.recurrenceRule, let preset = RecurrencePreset.from(rule: rule) {
                return (preset.displayName, preset.icon, .teal)
            }
        }

        // Fall back to energy for tasks with a future due date
        return energyChip
    }

    /// Slim leading color bar (≈4 pt wide) colored by priority.
    /// Hidden (zero width) when priority is .none so the row layout is unchanged.
    @ViewBuilder
    private var priorityBar: some View {
        if let barColor = priorityBarColor {
            barColor
                .frame(width: 4)
                .accessibilityHidden(true)
        }
    }

    private var priorityBarColor: Color? {
        guard !task.isCompleted else { return nil }
        switch task.priority {
        case .high:   return .red
        case .medium: return .orange
        case .low:    return .blue
        case .none:   return nil
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

    private var cardBackgroundTint: Color {
        if task.isCompleted {
            return Color.clear
        } else if isOverdue {
            return Color.red.opacity(0.04)
        } else if isDueToday {
            return Color.orange.opacity(0.04)
        } else if task.scheduledForToday {
            return Color.green.opacity(0.04)
        } else {
            return Color.clear
        }
    }

    private var cardBorderColor: Color {
        if task.isCompleted {
            return Color(uiColor: .separator).opacity(0.15)
        } else if isOverdue {
            return Color.red.opacity(0.35)
        } else if isDueToday {
            return Color.orange.opacity(0.35)
        } else if task.scheduledForToday {
            return Color.green.opacity(0.35)
        } else {
            return Color(uiColor: .separator).opacity(0.2)
        }
    }

    private var cardShadowColor: Color {
        if task.isCompleted {
            return .primary.opacity(0.01)
        } else {
            return .primary.opacity(0.05)
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
