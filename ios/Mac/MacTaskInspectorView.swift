// MacTaskInspectorView.swift
// Pepinillo — native macOS task inspector
//
// Reuses the shared TaskDetailFeature for editing and persistence. The
// presentation is a native macOS inspector: a compact header, a grouped form,
// and a pinned primary action. It intentionally does not reuse the iOS card
// layout from TaskDetailView.

import SwiftUI
import ComposableArchitecture

struct MacTaskInspectorView: View {
    @Bindable var store: StoreOf<TaskDetailFeature>

    var onClose: () -> Void
    var onStartFocus: (UUID, String) -> Void
    var onToggleCompletion: (UUID) -> Void

    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case title
        case notes
        case newSubtask
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            if store.isLoading && store.subtasks.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                form
            }

            Divider()
            startFocusFooter
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear { store.send(.onAppear) }
        .onReceive(NotificationCenter.default.publisher(for: .macInspectorFocusTitleRequested)) { _ in
            focusedField = .title
        }
        .alert(
            String(localized: "Couldn't Save Changes"),
            isPresented: Binding(
                get: { store.mutationError != nil },
                set: { if !$0 { store.send(.mutationErrorDismissed) } }
            )
        ) {
            Button(String(localized: "OK")) { store.send(.mutationErrorDismissed) }
        } message: {
            Text(store.mutationError ?? "")
        }
        .alert(
            String(localized: "Couldn't Load Tasks"),
            isPresented: Binding(
                get: { store.loadError != nil },
                set: { if !$0 { store.send(.retryLoadTapped) } }
            )
        ) {
            Button(String(localized: "Retry")) { store.send(.retryLoadTapped) }
            Button(String(localized: "Cancel"), role: .cancel) {}
        } message: {
            Text(store.loadError ?? "")
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center, spacing: 10) {
            Button {
                onToggleCompletion(store.taskID)
            } label: {
                Image(systemName: store.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(store.isCompleted ? Color.green : Color.secondary)
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.plain)
            .help(
                store.isCompleted
                    ? String(localized: "Mark task as incomplete")
                    : String(localized: "Mark task as complete")
            )
            .accessibilityLabel(
                store.isCompleted
                    ? String(localized: "Mark task as incomplete")
                    : String(localized: "Mark task as complete")
            )

            TextField(
                String(localized: "Title"),
                text: Binding(
                    get: { store.title },
                    set: { store.send(.titleChanged($0)) }
                ),
                axis: .vertical
            )
            .font(.title3.weight(.semibold))
            .textFieldStyle(.plain)
            .focused($focusedField, equals: .title)
            .strikethrough(store.isCompleted)
            .foregroundStyle(store.isCompleted ? Color.secondary : Color.primary)
            .lineLimit(1...3)

            Button {
                onClose()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain)
            .help(String(localized: "Close Inspector"))
            .accessibilityLabel(String(localized: "Close Inspector"))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    // MARK: - Form

    private var form: some View {
        Form {
            notesSection
            planningSection
            subtasksSection
            focusHistorySection
        }
        .formStyle(.grouped)
    }

    private var notesSection: some View {
        Section {
            ZStack(alignment: .topLeading) {
                if store.notes.isEmpty {
                    Text(String(localized: "Notes"))
                        .foregroundStyle(.tertiary)
                        .padding(.top, 8)
                        .padding(.leading, 5)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }

                TextEditor(text: Binding(
                    get: { store.notes },
                    set: { store.send(.notesChanged($0)) }
                ))
                .font(.body)
                .scrollContentBackground(.hidden)
                .focused($focusedField, equals: .notes)
                .frame(minHeight: 84)
                .accessibilityLabel(String(localized: "Notes"))
            }
        } header: {
            Text(String(localized: "Notes"))
        }
    }

    private var planningSection: some View {
        Section {
            LabeledContent(String(localized: "Priority")) {
                Picker("", selection: Binding(
                    get: { store.priority },
                    set: { store.send(.priorityChanged($0)) }
                )) {
                    ForEach(TaskPriority.allCases.sorted(by: >), id: \.self) { priority in
                        Text(priority.displayName).tag(priority)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .accessibilityLabel(String(localized: "Priority"))
            }

            LabeledContent(String(localized: "Energy")) {
                Picker("", selection: Binding(
                    get: { store.energyLevel },
                    set: { store.send(.energyLevelChanged($0)) }
                )) {
                    ForEach(EnergyLevel.allCases, id: \.self) { level in
                        Label(level.displayName, systemImage: level.icon).tag(level)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .accessibilityLabel(String(localized: "Energy"))
            }

            LabeledContent(String(localized: "Estimate")) {
                Stepper(value: Binding(
                    get: { store.estimatedPomodoros },
                    set: { store.send(.estimatedPomodorosChanged($0)) }
                ), in: 1...8) {
                    Text("\(store.estimatedPomodoros)")
                        .monospacedDigit()
                }
                .accessibilityLabel(String(localized: "Estimate"))
                .accessibilityValue("\(store.estimatedPomodoros)")
            }

            Toggle(isOn: Binding(
                get: { store.scheduledForToday },
                set: { store.send(.scheduledForTodayChanged($0)) }
            )) {
                Text(String(localized: "Scheduled for Today"))
            }

            dueDateRow
        } header: {
            Text(String(localized: "Planning"))
        }
    }

    private var dueDateRow: some View {
        LabeledContent(String(localized: "Due Date")) {
            HStack(spacing: 8) {
                if let dueDate = store.dueDate {
                    DatePicker(
                        "",
                        selection: Binding(
                            get: { dueDate },
                            set: { store.send(.dueDateChanged($0)) }
                        ),
                        displayedComponents: .date
                    )
                    .labelsHidden()
                    .accessibilityLabel(String(localized: "Due Date"))

                    Button {
                        store.send(.dueDateChanged(nil))
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                    .help(String(localized: "Remove Due Date"))
                    .accessibilityLabel(String(localized: "Remove Due Date"))
                } else {
                    Button(String(localized: "Add")) {
                        store.send(.dueDateChanged(Calendar.current.startOfDay(for: .now)))
                    }
                    .buttonStyle(.borderless)
                }
            }
        }
    }

    private var subtasksSection: some View {
        Section {
            ForEach(store.subtasks) { subtask in
                HStack(spacing: 8) {
                    Button {
                        store.send(.subtaskToggled(subtask.id))
                    } label: {
                        Image(systemName: subtask.isCompleted ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(subtask.isCompleted ? Color.green : Color.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(
                        subtask.isCompleted
                            ? String(localized: "Mark task as incomplete")
                            : String(localized: "Mark task as complete")
                    )

                    Text(subtask.title)
                        .strikethrough(subtask.isCompleted)
                        .foregroundStyle(subtask.isCompleted ? Color.secondary : Color.primary)

                    Spacer(minLength: 8)

                    Button {
                        store.send(.subtaskDeleted(subtask.id))
                    } label: {
                        Image(systemName: "xmark.circle")
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                    .help(String(localized: "Delete"))
                    .accessibilityLabel(String(localized: "Delete \(subtask.title)"))
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
                .focused($focusedField, equals: .newSubtask)
                .onSubmit { store.send(.addSubtaskTapped) }
            } else {
                Button {
                    store.send(.paywallTapped)
                } label: {
                    Label(String(localized: "Subtasks (Pepinillo+)"), systemImage: "lock.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        } header: {
            HStack {
                Text(String(localized: "Subtasks"))
                Spacer()
                let completed = store.subtasks.filter(\.isCompleted).count
                if !store.subtasks.isEmpty {
                    Text("\(completed)/\(store.subtasks.count)")
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
        }
    }

    private var focusHistorySection: some View {
        Section {
            LabeledContent(String(localized: "Total Focus Time")) {
                Text(formatDuration(store.totalFocusSeconds))
                    .monospacedDigit()
            }

            LabeledContent(String(localized: "Completed Pomodoros")) {
                Text("\(store.completedPomodoros)")
                    .monospacedDigit()
            }

            if store.sessions.isEmpty {
                Text(String(localized: "No focus sessions yet."))
                    .foregroundStyle(.secondary)
            } else {
                ForEach(store.sessions.prefix(5)) { session in
                    HStack(spacing: 10) {
                        Image(systemName: "timer")
                            .foregroundStyle(.secondary)
                            .accessibilityHidden(true)

                        VStack(alignment: .leading, spacing: 1) {
                            Text(FocusMode(rawValue: session.mode)?.macDisplayName ?? session.mode.capitalized)
                                .font(.callout)
                            Text(session.startedAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer(minLength: 8)

                        Text(formatDuration(session.actualDuration))
                            .font(.callout)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }
            }
        } header: {
            Text(String(localized: "Focus History"))
        }
    }

    // MARK: - Footer

    private var startFocusFooter: some View {
        HStack(spacing: 10) {
            Button {
                onStartFocus(store.taskID, store.title)
            } label: {
                Label(String(localized: "Start Focus Session"), systemImage: "play.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(store.isCompleted)
        }
        .padding(12)
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
