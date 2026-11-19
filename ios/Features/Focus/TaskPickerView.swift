// TaskPickerView.swift
// Pepinillo — Deep Work Companion for Apple
//
// Bottom sheet for linking/unlinking tasks to the active focus session.
// Shows incomplete tasks with energy icons; tapping links the task.

import SwiftUI
import ComposableArchitecture

struct TaskPickerView: View {
    let linkedTaskID: UUID?
    let tasks: IdentifiedArrayOf<TaskListFeature.TaskItemState>
    let onSelectTask: (UUID, String, String) -> Void
    let onUnlink: () -> Void
    @Environment(\.dismiss) private var dismiss
    // Issue #929: parity with the Mac popover — filter the active list by
    // title. Not auto-focused: popping the keyboard over a sheet uninvited
    // is an iOS etiquette violation; the field is one tap away.
    @State private var searchQuery = ""

    private var activeTasks: [TaskListFeature.TaskItemState] {
        tasks.filter { !$0.isCompleted }
    }

    /// Case- and diacritic-insensitive title filter; empty query = all.
    private var filteredTasks: [TaskListFeature.TaskItemState] {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return activeTasks }
        return activeTasks.filter { $0.title.localizedStandardContains(query) }
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
                    TextField(
                        String(localized: "Search Tasks"),
                        text: $searchQuery
                    )
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                    if filteredTasks.isEmpty {
                        if searchQuery.isEmpty {
                            Text(String(localized: "No active tasks"))
                                .foregroundStyle(.secondary)
                        } else {
                            Text(String(localized: "No Matches"))
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        ForEach(filteredTasks) { task in
                            Button {
                                HapticManager.selection()
                                onSelectTask(task.id, task.title, task.energyLevel.icon)
                                dismiss()
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: task.energyLevel.icon)
                                        .font(.body)
                                        .symbolRenderingMode(.hierarchical)
                                        .foregroundStyle(task.energyLevel.color)
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
            #if os(macOS)
            .listStyle(.inset)
            #else
            .listStyle(.insetGrouped)
            #endif
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
