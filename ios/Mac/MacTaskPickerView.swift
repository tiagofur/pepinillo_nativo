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
            // Return is handled exclusively by the key monitor below — it
            // sees every Return while the picker is up, so a submit handler
            // here would be dead code.
            .onAppear {
                isSearchFocused = true
                // Issues #993 (S3) / #1021 (S1–S2): ⌘↩ links the first match
                // and starts if idle; keypad Enter behaves like Return; with
                // zero matches our keys are CONSUMED so they never fall
                // through to the Start/Pause menu item (⌘↩). Local monitor:
                // intercepts BEFORE that menu equivalent can fire.
                monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                    // IME composition (japanese/chinese/korean): Return
                    // confirms the marked text and is never ours to take
                    // (dual review of #1035 — the field editor owns it).
                    if let client = NSApp.keyWindow?.firstResponder as? NSTextInputClient,
                       client.hasMarkedText() {
                        return event
                    }
                    // Key auto-repeat of our keys: the first press already
                    // acted; a repeat must not re-link (and one arriving
                    // after dismissal would otherwise reach Start/Pause).
                    if event.isARepeat,
                       event.keyCode == QuickOpenKeyDecision.returnKeyCode
                        || event.keyCode == QuickOpenKeyDecision.keypadEnterKeyCode {
                        return nil
                    }
                    // Only our keys: any modifier, or Return/keypad Enter.
                    guard event.modifierFlags.contains(.command)
                            || event.keyCode == QuickOpenKeyDecision.returnKeyCode
                            || event.keyCode == QuickOpenKeyDecision.keypadEnterKeyCode
                    else { return event }
                    switch QuickOpenKeyDecision.decide(
                        keyCode: Int(event.keyCode),
                        hasCommand: event.modifierFlags.contains(.command),
                        hasMatches: !filteredTasks.isEmpty
                    ) {
                    case .passThrough:
                        return event
                    case .consume:
                        // #1021 S1: ⌘↩ on the picker with no matches must not
                        // start a bare session via the menu shortcut.
                        return nil
                    case .link:
                        if let first = filteredTasks.first {
                            onSelectTask(first.id, first.title, first.energyLevel.icon)
                            dismiss()
                        }
                        return nil
                    case .linkAndStart:
                        if let first = filteredTasks.first {
                            onSelectTask(first.id, first.title, first.energyLevel.icon)
                            dismiss()
                            // Inside the success path: a broken hasMatches
                            // invariant must never start a bare session.
                            onLinkAndStart?()
                        }
                        return nil
                    }
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
