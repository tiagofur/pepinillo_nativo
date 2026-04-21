// iPadSplitView.swift
// Pepinillo — Deep Work Companion for Apple
//
// Adaptive NavigationSplitView layout for iPad and Mac.
// Sidebar: Focus, Plan, Dashboard, Account top-level areas.
// Plan uses three columns; other areas use two columns.

import SwiftUI
import ComposableArchitecture

// MARK: - iPad / Mac Split View

struct iPadSplitView: View {
    @Bindable var store: StoreOf<AppFeature>
    @State private var columnVisibility: NavigationSplitViewVisibility = .doubleColumn

    var body: some View {
        Group {
            if store.selectedTab == .plan {
                // Three-column layout for Plan — Mail-style adaptive:
                // Landscape: sidebar + task list + detail
                // Portrait: sidebar auto-hidden, task list + detail
                NavigationSplitView(columnVisibility: $columnVisibility) {
                    sidebarColumn
                } content: {
                    TaskListView(store: store.scope(state: \.tasks, action: \.tasks), isInSplitView: true)
                        .navigationSplitViewColumnWidth(min: 320, ideal: 400, max: 500)
                } detail: {
                    TaskDetailColumn(store: store.scope(state: \.tasks, action: \.tasks))
                }
                .navigationSplitViewStyle(.balanced)
            } else {
                // Two-column layout for other tabs (sidebar + detail)
                NavigationSplitView {
                    sidebarColumn
                } detail: {
                    detailColumn
                }
                .navigationSplitViewStyle(.balanced)
            }
        }
        .sheet(item: $store.scope(state: \.calendar, action: \.calendar)) { calendarStore in
            NavigationStack {
                CalendarView(store: calendarStore)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button(String(localized: "Done")) { store.send(.calendarSheetDismissed) }
                        }
                    }
            }
            .iPadSheetSizing()
        }
    }

    // MARK: - Sidebar Column

    @Environment(\.appTheme) private var theme

    private var sidebarColumn: some View {
        List {
            // Greeting header
            Section {
                Button {
                    if store.isSignedIn {
                        store.send(.showProfile)
                    } else {
                        store.send(.showAuth)
                    }
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(sidebarGreeting)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Text(store.displayName ?? String(localized: "Pepinillo"))
                            .font(.title2.weight(.bold))
                            .foregroundStyle(.primary)

                        if store.analytics.currentStreakDays > 0 {
                            HStack(spacing: 5) {
                                Image(systemName: "flame.fill")
                                    .font(.caption2)
                                    .foregroundStyle(theme.streakColor)
                                Text(String(localized: "\(store.analytics.currentStreakDays) day streak"))
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(theme.streakColor)
                            }
                            .padding(.top, 2)
                        }

                        if !store.isSignedIn {
                            Label(String(localized: "Log in"), systemImage: "person.crop.circle.badge.plus")
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.top, 6)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }

            // Main tabs
            Section {
                ForEach(AppFeature.Tab.allCases, id: \.self) { tab in
                    sidebarTabButton(tab)
                }
            }

            // Extra features below tabs
            Section {
                Button {
                    store.send(.weeklyReviewTapped)
                } label: {
                    Label(String(localized: "Weekly Review"), systemImage: "calendar.badge.clock")
                }

                Button {
                    store.send(.calendarTapped)
                } label: {
                    Label(String(localized: "Calendar"), systemImage: "calendar")
                }
            }
        }
        .navigationTitle("")
        .toolbar(.hidden, for: .navigationBar)
        .navigationSplitViewColumnWidth(min: 240, ideal: 320, max: 380)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
                Divider()

                if !store.subscriptionState.isPro {
                    Button {
                        store.send(.upgradeTapped)
                    } label: {
                        Label(String(localized: "Upgrade to Pro"), systemImage: "crown")
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.accentColor)
                }

                if store.isSignedIn {
                    Button {
                        store.send(.signOutTapped)
                    } label: {
                        Label(String(localized: "Sign out"), systemImage: "rectangle.portrait.and.arrow.right")
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.red)
                }

            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if store.selectedTab == .plan {
                    Button {
                        store.send(.tasks(.addTaskTapped))
                    } label: {
                        Image(systemName: "plus")
                    }
                    .keyboardShortcut("n", modifiers: .command)
                }
            }
        }
    }

    // MARK: - Detail Column (non-task tabs)

    @ViewBuilder
    private var detailColumn: some View {
        switch store.selectedTab {
        case .focus:
            FocusView(store: store.scope(state: \.focus, action: \.focus))
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)

        case .dashboard:
            AnalyticsView(store: store.scope(state: \.analytics, action: \.analytics))

        case .account:
            AccountView(store: store)

        case .plan:
            EmptyView() // Handled by three-column layout
        }
    }

    // MARK: - Sidebar Helpers

    private func sidebarTabButton(_ tab: AppFeature.Tab) -> some View {
        let isSelected = store.selectedTab == tab
        return Button {
            store.send(.tabSelected(tab))
        } label: {
            Label(tab.title, systemImage: tab.systemImage)
        }
        .listRowBackground(isSelected ? Color.accentColor.opacity(0.15) : nil)
        .foregroundStyle(isSelected ? Color.accentColor : .primary)
    }

    // MARK: - Greeting

    private var sidebarGreeting: String {
        let hour = Calendar.current.component(.hour, from: .now)
        switch hour {
        case 5..<12:
            return String(localized: "Good morning,")
        case 12..<18:
            return String(localized: "Good afternoon,")
        default:
            return String(localized: "Good evening,")
        }
    }
}

// MARK: - Task Detail Column (iPad split view)

/// Shows the selected task detail inline, or a placeholder when no task is selected.
private struct TaskDetailColumn: View {
    @Bindable var store: StoreOf<TaskListFeature>

    var body: some View {
        if let detailStore = $store.scope(state: \.detail, action: \.detail).wrappedValue {
            TaskDetailView(store: detailStore, isSheet: false)
        } else {
            ContentUnavailableView(
                String(localized: "Select a Task"),
                systemImage: "checkmark.circle",
                description: Text(String(localized: "Pick a task from the list to view details."))
            )
        }
    }
}
