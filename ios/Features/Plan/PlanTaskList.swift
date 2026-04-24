// PlanTaskList.swift
// Pepinillo — Deep Work Companion for Apple
//
// Content column of the Plan NavigationSplitView.
// Shows tasks filtered by the active PlanFilter.
// On iPhone (compact), this IS the full Plan screen (NavigationSplitView collapses).
// On iPad, this is the middle column; tapping a task sets selectedTaskID and
// opens TaskDetailView in the detail column instead of pushing a sheet.

import SwiftUI
import ComposableArchitecture

struct PlanTaskList: View {
    @Bindable var store: StoreOf<TaskListFeature>
    let filter: PlanFilter
    var showsTitle: Bool = true
    @State private var collapsedSections: Set<PlanFilter> = []
    @State private var taskToDelete: UUID?

    // MARK: - Filtered tasks

    private var filteredTasks: IdentifiedArrayOf<TaskListFeature.TaskItemState> {
        switch filter {
        case .today:
            return store.tasks.filter { $0.scheduledForToday && !$0.isCompleted }
        case .inbox:
            return store.tasks.filter { !$0.isCompleted && !$0.scheduledForToday && $0.dueDate == nil }
        case .upcoming:
            let cal = Calendar.current
            let now = Date.now
            let weekFromNow = cal.date(byAdding: .day, value: 7, to: now) ?? now
            return store.tasks.filter { task in
                guard !task.isCompleted, !task.scheduledForToday, let due = task.dueDate else { return false }
                return due > cal.startOfDay(for: now) && due <= weekFromNow
            }
        case .completed:
            return store.tasks.filter { $0.isCompleted }
        }
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            taskListContent
                .overlay(alignment: .bottom) {
                    if let deletedTask = store.recentlyDeletedTask {
                        undoBanner(taskTitle: deletedTask.title)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                            .padding(.bottom, 60)
                    }
                }
                .animation(.spring(), value: store.recentlyDeletedTask != nil)
        }
        .navigationTitle(showsTitle ? filter.title : "")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Section(String(localized: "Sort by")) {
                        ForEach(TaskListFeature.SortOrder.allCases, id: \.self) { order in
                            Button { store.send(.sortOrderChanged(order)) } label: {
                                if store.sortOrder == order {
                                    Label(order.displayName, systemImage: "checkmark")
                                } else {
                                    Text(order.displayName)
                                }
                            }
                        }
                    }
                    Divider()
                    Button {
                        store.send(.importFromRemindersTapped)
                    } label: {
                        Label(String(localized: "Import from Reminders"), systemImage: "square.and.arrow.down")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel(String(localized: "More options"))
            }
        }
        .safeAreaInset(edge: .bottom) {
            addTaskBar
        }
        .onAppear { store.send(.onAppear) }
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

    // MARK: - Task List Content

    @ViewBuilder
    private var taskListContent: some View {
        if store.isLoading {
            ProgressView()
                .frame(maxHeight: .infinity)
        } else if filteredTasks.isEmpty {
            ContentUnavailableView(
                emptyTitle,
                systemImage: filter.systemImage,
                description: Text(emptyDescription)
            )
            .frame(maxHeight: .infinity)
        } else {
            List {
                ForEach(filteredTasks) { task in
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
                        taskToDelete = filteredTasks[index].id
                        store.send(.taskDeleted(filteredTasks[index].id))
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color.clear)
            .refreshable { store.send(.onAppear) }
        }
    }

    // MARK: - Empty State Helpers

    private var emptyTitle: String {
        switch filter {
        case .today:     return String(localized: "Nothing for Today")
        case .inbox:     return String(localized: "Inbox Clear")
        case .upcoming:  return String(localized: "Nothing Upcoming")
        case .completed: return String(localized: "No Completed Tasks")
        }
    }

    private var emptyDescription: String {
        switch filter {
        case .today:     return String(localized: "Add tasks below to plan your day.")
        case .inbox:     return String(localized: "All tasks are organized.")
        case .upcoming:  return String(localized: "No tasks due in the next 7 days.")
        case .completed: return String(localized: "Complete a task to see it here.")
        }
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

}
