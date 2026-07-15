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
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 20)
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
                .textFieldStyle(.plain)
                .focused($focusedField, equals: .title)
                .strikethrough(store.isCompleted)
                .foregroundStyle(store.isCompleted ? .secondary : .primary)
            }
            .padding(.vertical, 2)
        }
        .padding(16)
        .pepinilloGlass(cornerRadius: GlassCornerRadius.card)
    }

    private var subtasksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            let completed = store.subtasks.filter(\.isCompleted).count
            let total = store.subtasks.count
            
            Text(total > 0 ? String(localized: "Subtasks (\(completed)/\(total))") : String(localized: "Subtasks"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.bottom, 4)

            VStack(spacing: 12) {
                if let loadError = store.loadError {
                    VStack(spacing: 8) {
                        Text(loadError)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        Button(String(localized: "Retry")) {
                            store.send(.retryLoadTapped)
                        }
                        .buttonStyle(.bordered)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                } else if store.subtasks.isEmpty && store.isLoading {
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
                                .frame(minWidth: 44, minHeight: 44)  // HIG 44pt minimum (issue #90)
                                .contentShape(Rectangle())
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
                                .frame(minWidth: 44, minHeight: 44)  // HIG 44pt minimum (issue #90)
                                .contentShape(Rectangle())
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
            .pepinilloGlass(cornerRadius: GlassCornerRadius.card)
        }
    }

    private var schedulingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle(isOn: Binding(
                get: { store.scheduledForToday },
                set: { store.send(.scheduledForTodayChanged($0)) }
            )) {
                Label(String(localized: "Focus Today"), systemImage: "bolt.fill")
                    .font(.body.weight(.semibold))
            }
            .toggleStyle(.switch)
            .tint(.orange)

            Divider()
                .opacity(0.1)

            if store.dueDate != nil {
                HStack(alignment: .center, spacing: 12) {
                    Label(String(localized: "Due Date"), systemImage: "calendar")
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 12)
                    DatePicker(
                        String(localized: "Due Date"),
                        selection: Binding(
                            get: { store.dueDate ?? Date() },
                            set: { store.send(.dueDateChanged($0)) }
                        ),
                        displayedComponents: .date
                    )
                    .labelsHidden()
                }

                Button(String(localized: "Remove Due Date"), role: .destructive) {
                    store.send(.dueDateChanged(nil))
                }
                .buttonStyle(.borderless)
                .font(.subheadline.weight(.medium))
                .frame(maxWidth: .infinity, alignment: .trailing)
            } else {
                Button {
                    store.send(.dueDateChanged(Calendar.current.date(byAdding: .day, value: 1, to: .now)))
                } label: {
                    HStack(spacing: 12) {
                        Label(String(localized: "Add due date"), systemImage: "calendar.badge.plus")
                            .foregroundStyle(.secondary)
                        Spacer(minLength: 4)
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .pepinilloGlass(cornerRadius: GlassCornerRadius.card)
    }

    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "Priority & Focus"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.bottom, 4)

            VStack(spacing: 14) {
                planEditorRow(String(localized: "Priority"), systemImage: "arrow.up") {
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
                    .labelsHidden()
                    .pickerStyle(.menu)
                }

                Divider().opacity(0.1)

                planEditorRow(String(localized: "Energy"), systemImage: "brain.head.profile") {
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
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .fixedSize()
                }

                Divider().opacity(0.1)

                planEditorRow(String(localized: "Pomodoros"), systemImage: "timer") {
                    HStack(spacing: 4) {
                        // Decrement — ≥44pt target
                        Button {
                            let current = store.estimatedPomodoros
                            if current > 1 { store.send(.estimatedPomodorosChanged(current - 1)) }
                        } label: {
                            Image(systemName: "minus")
                                .font(.body.weight(.semibold))
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(store.estimatedPomodoros <= 1 ? Color.secondary : Color.primary)
                        .disabled(store.estimatedPomodoros <= 1)
                        .accessibilityLabel(String(localized: "Decrease pomodoros"))

                        Text("\(store.estimatedPomodoros)")
                            .font(NumericFont.inline())
                            .foregroundStyle(.primary)
                            .frame(minWidth: 24, alignment: .center)

                        // Increment — ≥44pt target
                        Button {
                            let current = store.estimatedPomodoros
                            if current < 8 { store.send(.estimatedPomodorosChanged(current + 1)) }
                        } label: {
                            Image(systemName: "plus")
                                .font(.body.weight(.semibold))
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(store.estimatedPomodoros >= 8 ? Color.secondary : Color.primary)
                        .disabled(store.estimatedPomodoros >= 8)
                        .accessibilityLabel(String(localized: "Increase pomodoros"))
                    }
                }

                if store.completedPomodoros > 0 {
                    LabeledContent(String(localized: "Completed")) {
                        Text(String(localized: "🍅 \(store.completedPomodoros)/\(store.estimatedPomodoros)"))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .pepinilloGlass(cornerRadius: GlassCornerRadius.card)
        }
    }

    private var recurrenceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "Recurrence"))
                .font(.subheadline)
                .foregroundStyle(.secondary)

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
            .pepinilloGlass(cornerRadius: GlassCornerRadius.card)
        }
    }

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "Notes"))
                .font(.subheadline)
                .foregroundStyle(.secondary)

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
            .pepinilloGlass(cornerRadius: GlassCornerRadius.card)
        }
    }

    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "Focus History"))
                .font(.subheadline)
                .foregroundStyle(.secondary)

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
            .pepinilloGlass(cornerRadius: GlassCornerRadius.card)
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
                .frame(minHeight: 56)
                .background(store.isCompleted ? Color.pepinilloSystemFill : Color.accentColor)
                .clipShape(RoundedRectangle(cornerRadius: GlassCornerRadius.control, style: .continuous))
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

    private func planEditorRow<Content: View>(
        _ title: String,
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Label(title, systemImage: systemImage)
                .foregroundStyle(.secondary)
            Spacer(minLength: 12)
            content()
        }
    }
}
