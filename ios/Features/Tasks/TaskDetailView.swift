// TaskDetailView.swift
// Pepinillo — Deep Work Companion for Apple
//
// Full task editing sheet with subtask management, metadata, notes, and focus history.

import SwiftUI
import ComposableArchitecture

struct TaskDetailView: View {
    @Bindable var store: StoreOf<TaskDetailFeature>
    var isSheet: Bool = true
    @FocusState private var focusedField: Field?

    enum Field: Hashable { case title, subtask, notes }

    var body: some View {
        Group {
            if isSheet {
                NavigationStack {
                    formContent
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button(String(localized: "Done")) {
                                    focusedField = nil
                                    store.send(.dismissTapped)
                                }
                            }
                        }
                }
            } else {
                formContent
            }
        }
    }

    private var formContent: some View {
        Form {
            titleSection
            subtasksSection
            schedulingSection
            metadataSection
            recurrenceSection
            notesSection
            if store.totalFocusSeconds > 0 {
                statsSection
            }
            actionsSection
            deleteSection
        }
        .navigationTitle(String(localized: "Task Details"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { store.send(.onAppear) }
        .confirmationDialog(
            String(localized: "All subtasks completed!"),
            isPresented: Binding(
                get: { store.showAllSubtasksCompletedPrompt },
                set: { if !$0 { store.send(.allSubtasksCompletedPromptDismissed) } }
            ),
            titleVisibility: .visible
        ) {
            Button(String(localized: "Complete Task")) {
                store.send(.allSubtasksCompletedConfirmed)
                HapticManager.notification(.success)
            }
            Button(String(localized: "Keep Open"), role: .cancel) {
                store.send(.allSubtasksCompletedPromptDismissed)
            }
        } message: {
            Text(String(localized: "Do you want to mark this task as complete?"))
        }
        .confirmationDialog(
            String(localized: "Delete Task?"),
            isPresented: Binding(
                get: { store.showDeleteConfirmation },
                set: { if !$0 { store.send(.deleteConfirmationDismissed) } }
            ),
            titleVisibility: .visible
        ) {
            Button(String(localized: "Delete"), role: .destructive) {
                store.send(.deleteConfirmed)
            }
        } message: {
            Text(String(localized: "This action cannot be undone."))
        }
        .sheet(item: $store.scope(state: \.taskAnalytics, action: \.taskAnalytics)) { analyticsStore in
            TaskAnalyticsView(store: analyticsStore)
                .presentationDetents([.large])
        }
    }

    // MARK: - Sections

    private var titleSection: some View {
        Section {
            HStack(spacing: 12) {
                Button {
                    store.send(.completionToggled)
                    HapticManager.notification(.success)
                } label: {
                    Image(systemName: store.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.title2)
                        .foregroundStyle(store.isCompleted ? .green : .secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(store.isCompleted
                    ? String(localized: "Mark task as incomplete")
                    : String(localized: "Mark task as complete"))

                TextField(
                    String(localized: "Task title"),
                    text: Binding(
                        get: { store.title },
                        set: { store.send(.titleChanged($0)) }
                    ),
                    axis: .vertical
                )
                .font(.title3.weight(.semibold))
                .focused($focusedField, equals: .title)
                .strikethrough(store.isCompleted)
                .foregroundStyle(store.isCompleted ? .secondary : .primary)
            }
            .padding(.vertical, 2)
        }
    }

    private var subtasksSection: some View {
        Section {
            if store.subtasks.isEmpty && store.isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
            }

            ForEach(store.subtasks) { subtask in
                HStack(spacing: 12) {
                    Button {
                        store.send(.subtaskToggled(subtask.id))
                        HapticManager.impact(.light)
                    } label: {
                        Image(systemName: subtask.isCompleted ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(subtask.isCompleted ? .green : .secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(subtask.isCompleted
                        ? String(localized: "Mark \(subtask.title) as incomplete")
                        : String(localized: "Mark \(subtask.title) as complete"))

                    Text(subtask.title)
                        .strikethrough(subtask.isCompleted)
                        .foregroundStyle(subtask.isCompleted ? .secondary : .primary)
                }
            }
            .onDelete { indexSet in
                for index in indexSet {
                    store.send(.subtaskDeleted(store.subtasks[index].id))
                }
            }

            TextField(
                String(localized: "Add subtask…"),
                text: Binding(
                    get: { store.newSubtaskTitle },
                    set: { store.send(.newSubtaskTitleChanged($0)) }
                )
            )
            .focused($focusedField, equals: .subtask)
            .submitLabel(.done)
            .onSubmit { store.send(.addSubtaskTapped) }
            .foregroundStyle(.secondary)
        } header: {
            let completed = store.subtasks.filter(\.isCompleted).count
            let total = store.subtasks.count
            if total > 0 {
                Text(String(localized: "Subtasks (\(completed)/\(total))"))
            } else {
                Text(String(localized: "Subtasks"))
            }
        }
    }

    private var schedulingSection: some View {
        Section {
            Toggle(
                String(localized: "Focus Today"),
                isOn: Binding(
                    get: { store.scheduledForToday },
                    set: { store.send(.scheduledForTodayChanged($0)) }
                )
            )
            .tint(.orange)

            if store.dueDate != nil {
                DatePicker(
                    String(localized: "Due Date"),
                    selection: Binding(
                        get: { store.dueDate ?? Date() },
                        set: { store.send(.dueDateChanged($0)) }
                    ),
                    displayedComponents: .date
                )
                Button(String(localized: "Remove Due Date"), role: .destructive) {
                    store.send(.dueDateChanged(nil))
                }
            } else {
                Button {
                    store.send(.dueDateChanged(Calendar.current.date(byAdding: .day, value: 1, to: .now)))
                } label: {
                    Label(String(localized: "Add Due Date"), systemImage: "calendar.badge.plus")
                }
            }
        }
    }

    private var metadataSection: some View {
        Section {
            Picker(
                String(localized: "Priority"),
                selection: Binding(
                    get: { store.priority },
                    set: { store.send(.priorityChanged($0)) }
                )
            ) {
                ForEach(TaskPriority.allCases, id: \.self) { priority in
                    HStack {
                        if priority != .none {
                            Image(systemName: priority.icon)
                        }
                        Text(priority.displayName)
                    }
                    .tag(priority)
                }
            }

            Picker(
                String(localized: "Energy"),
                selection: Binding(
                    get: { store.energyLevel },
                    set: { store.send(.energyLevelChanged($0)) }
                )
            ) {
                ForEach(EnergyLevel.allCases, id: \.self) { level in
                    Label(level.displayName, systemImage: level.icon).tag(level)
                }
            }

            Stepper(
                String(localized: "Pomodoros: \(store.estimatedPomodoros)"),
                value: Binding(
                    get: { store.estimatedPomodoros },
                    set: { store.send(.estimatedPomodorosChanged($0)) }
                ),
                in: 1...8
            )

            if store.completedPomodoros > 0 {
                LabeledContent(String(localized: "Completed")) {
                    Text("🍅 \(store.completedPomodoros)/\(store.estimatedPomodoros)")
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text(String(localized: "Priority & Focus"))
        }
    }

    private var recurrenceSection: some View {
        Section {
            if let rule = store.recurrenceRule, let preset = RecurrencePreset.from(rule: rule) {
                HStack {
                    Label(preset.displayName, systemImage: preset.icon)
                    Spacer()
                    Button(String(localized: "Remove")) {
                        store.send(.recurrenceChanged(nil))
                    }
                    .font(.subheadline)
                    .foregroundStyle(.red)
                    .accessibilityLabel(String(localized: "Remove recurrence"))
                }
            } else {
                Menu {
                    ForEach(RecurrencePreset.allCases, id: \.self) { preset in
                        Button {
                            store.send(.recurrenceChanged(preset.rawValue))
                        } label: {
                            Label(preset.displayName, systemImage: preset.icon)
                        }
                    }
                } label: {
                    Label(String(localized: "Set Repeat"), systemImage: "arrow.clockwise")
                }
            }
        } header: {
            Text(String(localized: "Recurrence"))
        }
    }

    private var notesSection: some View {
        Section {
            TextEditor(
                text: Binding(
                    get: { store.notes },
                    set: { store.send(.notesChanged($0)) }
                )
            )
            .focused($focusedField, equals: .notes)
            .frame(minHeight: 80)
        } header: {
            Text(String(localized: "Notes"))
        }
    }

    private var statsSection: some View {
        Section {
            LabeledContent(String(localized: "Total Focus Time")) {
                Text(formatDuration(store.totalFocusSeconds))
                    .foregroundStyle(.secondary)
            }
            LabeledContent(String(localized: "Completed Pomodoros")) {
                Text("\(store.completedPomodoros)")
                    .foregroundStyle(.secondary)
            }
            Button {
                store.send(.viewAnalyticsTapped)
            } label: {
                Label(String(localized: "Focus Analytics"), systemImage: "chart.bar.xaxis")
                    .foregroundStyle(.tint)
            }
            .accessibilityHint(String(localized: "View detailed focus session charts for this task"))
        } header: {
            Text(String(localized: "Focus History"))
        }
    }

    private var actionsSection: some View {
        Section {
            Button {
                store.send(.startFocusTapped)
                HapticManager.impact(.medium)
            } label: {
                Label(String(localized: "Start Focus Session"), systemImage: "play.circle.fill")
                    .foregroundStyle(.tint)
            }
            .disabled(store.isCompleted)
            .accessibilityLabel(String(localized: "Start focus session for this task"))
            .accessibilityHint(store.isCompleted ? String(localized: "Not available for completed tasks") : "")
        }
    }

    private var deleteSection: some View {
        Section {
            Button(String(localized: "Delete Task"), role: .destructive) {
                store.send(.deleteTapped)
            }
            .accessibilityHint(String(localized: "Permanently removes this task"))
        }
    }

    // MARK: - Helpers

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        if minutes < 60 {
            return String(localized: "\(minutes) min")
        }
        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        if remainingMinutes == 0 {
            return String(localized: "\(hours)h")
        }
        return String(localized: "\(hours)h \(remainingMinutes)m")
    }
}
