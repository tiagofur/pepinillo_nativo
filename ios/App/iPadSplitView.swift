// iPadSplitView.swift
// Pepinillo — Deep Work Companion for Apple
//
// Adaptive iPad / Mac layouts. Two concrete variants:
//
//   • iPadLandscapeLayout — NavigationSplitView (sidebar + detail). Sidebar
//     exposes ONLY the same 4 tabs as the iPhone TabView (Focus, Plan,
//     Dashboard, Account). Extras like Weekly Review and Calendar live inside
//     the Account tab — same as iPhone.
//
//   • iPadPortraitLayout — Top-menu navigation. A segmented control at the top
//     switches between the same 4 tabs; content fills the rest. Matches the
//     iPhone TabView spirit without collapsing columns.
//
// Detection (portrait vs landscape) happens in AppView.swift via GeometryReader
// because on iPad both orientations report horizontalSizeClass == .regular.

import SwiftUI
import ComposableArchitecture

// MARK: - Landscape: Sidebar + Detail

struct iPadLandscapeLayout: View {
    @Bindable var store: StoreOf<AppFeature>
    @Environment(\.appTheme) private var theme

    var body: some View {
        NavigationSplitView {
            sidebarColumn
        } detail: {
            detailColumn
        }
        .navigationSplitViewStyle(.balanced)
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

    // MARK: - Sidebar

    private var sidebarColumn: some View {
        List {
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

            Section {
                ForEach(AppFeature.Tab.allCases, id: \.self) { tab in
                    sidebarTabButton(tab)
                }
            }
        }
        .navigationTitle("")
        .toolbar(.hidden, for: .navigationBar)
        .navigationSplitViewColumnWidth(min: 240, ideal: 320, max: 380)
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

    // MARK: - Detail

    @ViewBuilder
    private var detailColumn: some View {
        NavigationStack {
            iPadTabContent(store: store, tab: store.selectedTab)
        }
    }

    // MARK: - Greeting

    private var sidebarGreeting: String {
        let hour = Calendar.current.component(.hour, from: .now)
        switch hour {
        case 5..<12:  return String(localized: "Good morning,")
        case 12..<18: return String(localized: "Good afternoon,")
        default:      return String(localized: "Good evening,")
        }
    }
}

// MARK: - Portrait: Top menu + content

struct iPadPortraitLayout: View {
    @Bindable var store: StoreOf<AppFeature>

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                topTabMenu
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)

                Divider()

                iPadTabContent(store: store, tab: store.selectedTab)
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

    private var topTabMenu: some View {
        Picker("", selection: Binding(
            get: { store.selectedTab },
            set: { store.send(.tabSelected($0)) }
        )) {
            ForEach(AppFeature.Tab.allCases, id: \.self) { tab in
                Label(tab.title, systemImage: tab.systemImage)
                    .tag(tab)
            }
        }
        .pickerStyle(.segmented)
    }
}

// MARK: - Shared tab content router (iPad portrait + landscape)

struct iPadTabContent: View {
    @Bindable var store: StoreOf<AppFeature>
    let tab: AppFeature.Tab

    var body: some View {
        switch tab {
        case .focus:
            FocusView(store: store.scope(state: \.focus, action: \.focus))
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)

        case .plan:
            PlanView(store: store.scope(state: \.tasks, action: \.tasks))

        case .dashboard:
            DashboardView(store: store.scope(state: \.analytics, action: \.analytics))

        case .account:
            AccountView(store: store)
        }
    }
}
