// TaskPickerView.swift
// Pepinillo — Deep Work Companion for Apple
//
// Bottom sheet for linking/unlinking tasks to the active focus session.
// Shows incomplete tasks with energy emoji; tapping links the task.

import SwiftUI
import ComposableArchitecture

struct TaskPickerView: View {
    let linkedTaskID: UUID?
    let tasks: IdentifiedArrayOf<TaskListFeature.TaskItemState>
    let onSelectTask: (UUID, String) -> Void
    let onUnlink: () -> Void
    @Environment(\.dismiss) private var dismiss

    private var activeTasks: [TaskListFeature.TaskItemState] {
        tasks.filter { !$0.isCompleted }
    }

    var body: some View {
        NavigationStack {
            List {
                if linkedTaskID != nil {
                    Section {
                        Button(role: .destructive) {
                            onUnlink()
                            dismiss()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "xmark.circle")
                                    .foregroundStyle(.red)
                                Text(String(localized: "Unlink Task"))
                                    .foregroundStyle(.red)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }

                Section(String(localized: "Tasks")) {
                    if activeTasks.isEmpty {
                        Text(String(localized: "No active tasks"))
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(activeTasks) { task in
                            Button {
                                HapticManager.selection()
                                onSelectTask(task.id, task.title)
                                dismiss()
                            } label: {
                                HStack(spacing: 10) {
                                    Text(task.energyLevel.emoji)
                                        .font(.body)
                                        .frame(width: 24)
                                    Text(task.title)
                                        .foregroundStyle(.primary)
                                        .lineLimit(2)
                                    Spacer()
                                    if task.id == linkedTaskID {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(Color.accentColor)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("\(task.title)\(task.id == linkedTaskID ? String(localized: ", currently linked") : "")")
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(String(localized: "Link Task"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "Done")) { dismiss() }
                }
            }
        }
    }
}

// MARK: - EnergyLevel emoji

extension EnergyLevel {
    var emoji: String {
        switch self {
        case .deep:    return "🧠"
        case .shallow: return "📋"
        case .admin:   return "📁"
        }
    }
}
