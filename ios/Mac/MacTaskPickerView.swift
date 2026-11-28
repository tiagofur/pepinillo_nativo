//
//  MacTaskPickerView.swift
//  Pepinillo — Deep Work Companion for Apple
//
//  The Focus ▸ Link Task picker (⌘K / chip), extracted verbatim from
//  MacFocusView.swift (issue #1021 S5 — mechanical seam, no behavior change).
//

import ComposableArchitecture
import SwiftUI

struct MacTaskPickerView: View {
    let linkedTaskID: UUID?
    let tasks: IdentifiedArrayOf<TaskListFeature.TaskItemState>
    let onSelectTask: (UUID, String, String) -> Void
    let onUnlink: () -> Void
    /// Issue #993 (S3): ⌘↩ links the first match and, if idle, starts the
    /// session with it. Nil = legacy plain-Return behavior only.
    var onLinkAndStart: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    // Issue #929: many-task plans made finding the one to link slow —
    // Spotlight-style search with Return selecting the first match.
    @State private var searchQuery = ""
    @FocusState private var isSearchFocused: Bool
    @State private var monitor: Any?

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
        VStack(alignment: .leading, spacing: 0) {
            // Popovers dismiss on outside click — no Done header (an iOS
            // sheet idiom). The title row just labels the popover.
            HStack {
                Text("Link Task")
                    .font(.headline)
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 6)

            TextField(
                String(localized: "Search Tasks"),
                text: $searchQuery
            )
            .textFieldStyle(.roundedBorder)
            .font(.body)
            .focused($isSearchFocused)
            .padding(.horizontal, 16)
            .padding(.bottom, 10)
            .onSubmit {
                // Spotlight flow: Return links the first match.
                if let first = filteredTasks.first {
                    onSelectTask(first.id, first.title, first.energyLevel.icon)
                    dismiss()
                }
            }
            .onAppear {
                isSearchFocused = true
                // Issue #993 (S3): ⌘↩ links the first match and starts if
                // idle. Local monitor: intercepts BEFORE the Start/Pause
                // menu equivalent (⌘↩) can fire while the popover is up.
                monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                    guard event.keyCode == 36, event.modifierFlags.contains(.command),
                          let first = filteredTasks.first else { return event }
                    onSelectTask(first.id, first.title, first.energyLevel.icon)
                    dismiss()
                    onLinkAndStart?()
                    return nil
                }
            }
            .onDisappear {
                if let monitor { NSEvent.removeMonitor(monitor) }
                monitor = nil
            }
            .accessibilityLabel(String(localized: "Search Tasks"))

            Divider()

            List {
                if linkedTaskID != nil {
                    Button(role: .destructive) {
                        onUnlink()
                        dismiss()
                    } label: {
                        Label("Unlink Task", systemImage: "xmark.circle")
                    }
                    .buttonStyle(.plain)
                }

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
                            onSelectTask(task.id, task.title, task.energyLevel.icon)
                            dismiss()
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: task.energyLevel.icon)
                                    .symbolRenderingMode(.hierarchical)
                                    .foregroundStyle(task.energyLevel.color)
                                    .frame(width: 22)
                                Text(task.title)
                                    .lineLimit(2)
                                Spacer()
                                if task.id == linkedTaskID {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(Color.accentColor)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(
                            task.title + (task.id == linkedTaskID
                                          ? String(localized: ", currently linked")
                                          : "")
                        )
                    }
                }
            }
            .listStyle(.inset)
        }
        .frame(width: 360, height: 420)
    }
}
