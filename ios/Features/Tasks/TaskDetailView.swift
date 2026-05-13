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
        .background(Color.clear)
    }

    private var formContent: some View {
        ScrollView {
            VStack(spacing: 20) {
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
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
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
                .pepinilloSheetStyle()
        }
    }

    // MARK: - Sections

    private var titleSection: some View {
        VStack {
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
        .padding(16)
        .pepinilloGlass()
    }

    private var subtasksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            let completed = store.subtasks.filter(\.isCompleted).count
            let total = store.subtasks.count
            
            Text(total > 0 ? String(localized: "Subtasks (\(completed)/\(total))") : String(localized: "Subtasks"))
                .font(.caption.bold())
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .padding(.bottom, 4)

            VStack(spacing: 12) {
                if store.subtasks.isEmpty && store.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
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

                        Text(subtask.title)
                            .strikethrough(subtask.isCompleted)
                            .foregroundStyle(subtask.isCompleted ? .secondary : .primary)
                        
                        Spacer()
                        
                        Button {
                            store.send(.subtaskDeleted(subtask.id))
                        } label: {
                            Image(systemName: "xmark.circle")
                                .foregroundStyle(.tertiary)
                        }
                        .buttonStyle(.plain)
                    }
                }

                if store.isProUser {
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
                    .padding(.top, 4)
                } else {
                    Button {
                        store.send(.paywallTapped)
                    } label: {
                        HStack {
                            Image(systemName: "lock.fill")
                                .font(.caption2)
                            Text(String(localized: "Subtasks (Pepinillo+)"))
                                .font(.body)
                            Spacer()
                        }
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 8)
                        .padding(.top, 4)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)
            .pepinilloGlass()
        }
    }

    private var schedulingSection: some View {
        VStack(spacing: 12) {
            Toggle(
                String(localized: "Focus Today"),
                isOn: Binding(
                    get: { store.scheduledForToday },
                    set: { store.send(.scheduledForTodayChanged($0)) }
                )
            )
            .tint(.orange)

            Divider()
                .opacity(0.1)

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
                .font(.subheadline)
            } else {
                Button {
                    store.send(.dueDateChanged(Calendar.current.date(byAdding: .day, value: 1, to: .now)))
                } label: {
                    Label(String(localized: "Add Due Date"), systemImage: "calendar.badge.plus")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(16)
        .pepinilloGlass()
    }

    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "Priority & Focus"))
                .font(.caption.bold())
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .padding(.bottom, 4)

            VStack(spacing: 16) {
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
                .pickerStyle(.menu)

                Divider().opacity(0.1)

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
                .pickerStyle(.menu)

                Divider().opacity(0.1)

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
            }
            .padding(16)
            .pepinilloGlass()
        }
    }

    private var recurrenceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "Recurrence"))
                .font(.caption.bold())
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            VStack {
                if let rule = store.recurrenceRule, let preset = RecurrencePreset.from(rule: rule) {
                    HStack {
                        Label(preset.displayName, systemImage: preset.icon)
                        Spacer()
                        Button(String(localized: "Remove")) {
                            store.send(.recurrenceChanged(nil))
                        }
                        .font(.subheadline)
                        .foregroundStyle(.red)
                    }
                } else {
                if store.isProUser {
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
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                } else {
                    Button {
                        store.send(.paywallTapped)
                    } label: {
                        HStack {
                            Label(String(localized: "Set Repeat (Pepinillo+)"), systemImage: "arrow.clockwise")
                            Spacer()
                            Image(systemName: "lock.fill")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }
                }
            }
            .padding(16)
            .pepinilloGlass()
        }
    }

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "Notes"))
                .font(.caption.bold())
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            TextEditor(
                text: Binding(
                    get: { store.notes },
                    set: { store.send(.notesChanged($0)) }
                )
            )
            .focused($focusedField, equals: .notes)
            .scrollContentBackground(.hidden)
            .background(Color.clear)
            .frame(minHeight: 120)
            .padding(12)
            .pepinilloGlass()
        }
    }

    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "Focus History"))
                .font(.caption.bold())
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            VStack(spacing: 14) {
                LabeledContent(String(localized: "Total Focus Time")) {
                    Text(formatDuration(store.totalFocusSeconds))
                        .foregroundStyle(.primary)
                }
                
                Divider().opacity(0.1)
                
                LabeledContent(String(localized: "Completed Pomodoros")) {
                    Text("\(store.completedPomodoros)")
                        .foregroundStyle(.primary)
                }
                
                Divider().opacity(0.1)

                Button {
                    store.send(.viewAnalyticsTapped)
                } label: {
                    Label(String(localized: "Focus Analytics"), systemImage: "chart.bar.xaxis")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
            }
            .padding(16)
            .pepinilloGlass()
        }
    }

    private var actionsSection: some View {
        Button {
            store.send(.startFocusTapped)
            HapticManager.impact(.medium)
        } label: {
            Label(String(localized: "Start Focus Session"), systemImage: "play.circle.fill")
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(store.isCompleted ? Color(.systemFill) : Color.accentColor)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: (store.isCompleted ? Color.clear : Color.accentColor.opacity(0.3)), radius: 8, y: 4)
        }
        .disabled(store.isCompleted)
    }

    private var deleteSection: some View {
        Button {
            store.send(.deleteTapped)
        } label: {
            Text(String(localized: "Delete Task"))
                .font(.subheadline.bold())
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
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
