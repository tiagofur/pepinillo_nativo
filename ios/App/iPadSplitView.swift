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
    }

    // MARK: - Sidebar

    private var sidebarColumn: some View {
        List {
            Section {
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
                }
                .frame(maxWidth: .infinity, alignment: .leading)
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

/// Native TabView (iPhone-style bottom tabs) with content constrained to a
/// comfortable max width so the UI doesn't sprawl across the full iPad width.
struct iPadPortraitLayout: View {
    @Bindable var store: StoreOf<AppFeature>

    private static let contentMaxWidth: CGFloat = 720

    var body: some View {
        TabView(selection: Binding(
            get: { store.selectedTab },
            set: { store.send(.tabSelected($0)) }
        )) {
            ForEach(AppFeature.Tab.allCases, id: \.self) { tab in
                tabContent(for: tab)
                    .tabItem {
                        Label(tab.title, systemImage: tab.systemImage)
                    }
                    .tag(tab)
            }
        }
    }

    @ViewBuilder
    private func tabContent(for tab: AppFeature.Tab) -> some View {
        switch tab {
        case .focus:
            NavigationStack {
                FocusView(store: store.scope(state: \.focus, action: \.focus))
                    .constrainedWidth(Self.contentMaxWidth)
            }

        case .plan:
            NavigationStack {
                PlanView(store: store.scope(state: \.tasks, action: \.tasks))
                    .constrainedWidth(Self.contentMaxWidth)
            }

        case .dashboard:
            NavigationStack {
                DashboardView(store: store.scope(state: \.analytics, action: \.analytics))
                    .constrainedWidth(Self.contentMaxWidth)
            }

        case .account:
            AccountView(store: store)
                .constrainedWidth(Self.contentMaxWidth)
        }
    }
}

// MARK: - Helpers

private extension View {
    /// Centers the view within the available width, capped at `maxWidth`.
    /// A full-width systemBackground fills the gap on the sides so the empty
    /// area matches the app's base background instead of showing white.
    func constrainedWidth(_ maxWidth: CGFloat) -> some View {
        self
            .frame(maxWidth: maxWidth)
            .frame(maxWidth: .infinity)
            .background(Color(.systemBackground).ignoresSafeArea())
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
