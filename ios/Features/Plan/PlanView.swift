// PlanView.swift
// Pepinillo — Deep Work Companion for Apple
//
// Plan tab — the user's planning surface.
// Shows tasks grouped into sections: Today, Inbox, Upcoming, Completed.
// Each section has its own header with count and collapse support.
// Replaces the flat filtered list with a true planning experience.

import SwiftUI
import ComposableArchitecture

struct PlanView: View {
    @Bindable var store: StoreOf<TaskListFeature>
    @State private var taskToDelete: UUID?
    @State private var collapsedSections: Set<PlanSection> = []

    // MARK: - Section enum

    enum PlanSection: String, CaseIterable {
        case today
        case inbox
        case upcoming
        case completed

        var title: String {
            switch self {
            case .today:     return String(localized: "Today")
            case .inbox:     return String(localized: "Inbox")
            case .upcoming:  return String(localized: "Upcoming")
            case .completed: return String(localized: "Completed")
            }
        }

        var icon: String {
            switch self {
            case .today:     return "flame.fill"
            case .inbox:     return "tray"
            case .upcoming:  return "calendar"
            case .completed: return "checkmark.circle"
            }
        }

        var headerColor: Color {
            switch self {
            case .today:     return .orange
            case .inbox:     return .blue
            case .upcoming:  return .purple
            case .completed: return .green
            }
        }
    }

    // MARK: - Grouped tasks

    private var todayTasks: IdentifiedArrayOf<TaskListFeature.TaskItemState> {
        store.tasks.filter { $0.scheduledForToday && !$0.isCompleted }
    }

    private var inboxTasks: IdentifiedArrayOf<TaskListFeature.TaskItemState> {
        store.tasks.filter { !$0.isCompleted && !$0.scheduledForToday && $0.dueDate == nil }
    }

    private var upcomingTasks: IdentifiedArrayOf<TaskListFeature.TaskItemState> {
        let cal = Calendar.current
        let now = Date.now
        let weekFromNow = cal.date(byAdding: .day, value: 7, to: now) ?? now
        return store.tasks.filter { task in
            guard !task.isCompleted, !task.scheduledForToday, let due = task.dueDate else { return false }
            return due > cal.startOfDay(for: now) && due <= weekFromNow
        }
    }

    private var completedTasks: IdentifiedArrayOf<TaskListFeature.TaskItemState> {
        store.tasks.filter { $0.isCompleted }
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
            taskSections
            addTaskBar
        }
        .overlay(alignment: .bottom) {
            if let deletedTask = store.recentlyDeletedTask {
                undoBanner(taskTitle: deletedTask.title)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.bottom, 60)
            }
        }
        .animation(.spring(), value: store.recentlyDeletedTask != nil)
        .navigationTitle(String(localized: "Plan"))
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                importMenu
            }
            ToolbarItem(placement: .topBarTrailing) {
                sortMenu
            }
        }
        .onAppear { store.send(.onAppear) }
        .modifier(TaskDetailSheetModifier(store: store))
        .alert(
            String(localized: "Import Failed"),
            isPresented: Binding(
                get: { store.importError != nil },
                set: { if !$0 { store.send(.importErrorDismissed) } }
            )
        ) {
            Button(String(localized: "OK")) { store.send(.importErrorDismissed) }
        } message: {
            Text(store.importError ?? "")
        }
    }
}

    // MARK: - Task Sections

    private var taskSections: some View {
        Group {
            if store.isLoading {
                ProgressView()
                    .frame(maxHeight: .infinity)
            } else if store.tasks.isEmpty {
                ContentUnavailableView(
                    String(localized: "No Tasks Yet"),
                    systemImage: "tray",
                    description: Text(String(localized: "Add your first task below to start planning."))
                )
                .frame(maxHeight: .infinity)
            } else {
                List {
                    planSection(.today, tasks: todayTasks)
                    planSection(.inbox, tasks: inboxTasks)
                    planSection(.upcoming, tasks: upcomingTasks)
                    if !completedTasks.isEmpty {
                        planSection(.completed, tasks: completedTasks)
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .refreshable { store.send(.onAppear) }
            }
        }
    }

    // MARK: - Section Builder

    private func planSection(_ section: PlanSection, tasks: IdentifiedArrayOf<TaskListFeature.TaskItemState>) -> some View {
        Section {
            if !collapsedSections.contains(section) {
                if tasks.isEmpty {
                    Text(section == .today
                         ? String(localized: "No tasks scheduled for today")
                         : String(localized: "Nothing here"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 4)
                } else {
                    ForEach(tasks) { task in
                        TaskRow(
                            task: task,
                            onTap: { store.send(.taskTapped(task.id)) },
                            onComplete: { store.send(.taskCompleted(task.id)) },
                            onStartFocus: { store.send(.startFocusOnTask(task.id)) },
                            onScheduledForTodayToggled: {
                                store.send(.taskScheduledForToday(task.id, !task.scheduledForToday))
                            },
                            onEnergyChanged: { level in
                                store.send(.energyLevelChanged(task.id, level))
                            },
                            onRecurrenceChanged: { rule in
                                store.send(.recurrenceChanged(task.id, rule))
                            }
                        )
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            Button {
                                store.send(.taskScheduledForToday(task.id, !task.scheduledForToday))
                                HapticManager.impact(.light)
                            } label: {
                                Label(
                                    task.scheduledForToday
                                        ? String(localized: "Remove from Today")
                                        : String(localized: "Add to Today"),
                                    systemImage: task.scheduledForToday ? "minus.circle" : "bolt.circle.fill"
                                )
                            }
                            .tint(task.scheduledForToday ? .gray : .orange)
                        }
                    }
                    .onDelete { indexSet in
                        if let index = indexSet.first {
                            taskToDelete = tasks[index].id
                        }
                    }
                }
            }
        } header: {
            sectionHeader(section, count: tasks.count)
                .onTapGesture {
                    withAnimation(.spring(response: 0.3)) {
                        if collapsedSections.contains(section) {
                            collapsedSections.remove(section)
                        } else {
                            collapsedSections.insert(section)
                        }
                    }
                }
        }
    }

    // MARK: - Section Header

    private func sectionHeader(_ section: PlanSection, count: Int) -> some View {
        HStack(spacing: 8) {
            Image(systemName: section.icon)
                .font(.caption)
                .foregroundStyle(section.headerColor)

            Text(section.title)
                .font(.subheadline.weight(.semibold))

            if count > 0 {
                Text("\(count)")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .background(section.headerColor.opacity(0.8), in: Capsule())
            }

            Spacer()

            Image(systemName: collapsedSections.contains(section) ? "chevron.right" : "chevron.down")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .pepinilloGlass(cornerRadius: 12)
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 4, trailing: 16))
        .listRowBackground(Color.clear)
    }

    // MARK: - Add Task Bar

    private var addTaskBar: some View {
        HStack(spacing: 12) {
            TextField(
                String(localized: "Add a task…"),
                text: Binding(
                    get: { store.newTaskTitle },
                    set: { store.send(.newTaskTitleChanged($0)) }
                )
            )
            .textFieldStyle(.roundedBorder)
            .submitLabel(.done)
            .onSubmit { store.send(.addTaskTapped) }

            Button {
                HapticManager.impact(.light)
                store.send(.addTaskTapped)
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.tint)
            }
            .disabled(store.newTaskTitle.trimmingCharacters(in: .whitespaces).isEmpty)
            .accessibilityLabel(String(localized: "Add new task"))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .pepinilloGlass(cornerRadius: 32)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    // MARK: - Undo Banner

    private func undoBanner(taskTitle: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "trash")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("\"\(taskTitle)\" deleted")
                .font(.subheadline)
                .lineLimit(1)
            Spacer()
            Button {
                HapticManager.impact(.light)
                store.send(.undoDeleteTask)
            } label: {
                Text(String(localized: "Undo"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.tint)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .pepinilloGlass(cornerRadius: 12)
        .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
        .padding(.horizontal, 16)
    }

    // MARK: - Toolbar

    private var importMenu: some View {
        Menu {
            Button {
                store.send(.importFromRemindersTapped)
            } label: {
                Label(String(localized: "Import from Reminders"), systemImage: "list.bullet.rectangle")
            }
        } label: {
            Image(systemName: "square.and.arrow.down")
        }
        .accessibilityLabel(String(localized: "Import tasks"))
    }

    private var sortMenu: some View {
        Menu {
            ForEach(TaskListFeature.SortOrder.allCases, id: \.self) { order in
                Button {
                    store.send(.sortOrderChanged(order))
                } label: {
                    HStack {
                        Label(order.displayName, systemImage: order.icon)
                        if store.sortOrder == order {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down")
        }
        .accessibilityLabel(String(localized: "Sort tasks"))
    }
}
