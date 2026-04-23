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

// MARK: - Unified iPad Layout: Sidebar + Detail

struct iPadLayout: View {
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
            .listRowSeparator(.hidden)
        }
        .scrollContentBackground(.hidden)
        .navigationTitle("")
        .toolbar(.hidden, for: .navigationBar)
        .navigationSplitViewColumnWidth(min: 240, ideal: 280, max: 320)
    }

    private func sidebarTabButton(_ tab: AppFeature.Tab) -> some View {
        let isSelected = store.selectedTab == tab
        return Button {
            store.send(.tabSelected(tab))
        } label: {
            Label(tab.title, systemImage: tab.systemImage)
                .font(.headline)
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.accentColor.opacity(0.15))
                            .pepinilloGlass(cornerRadius: 12)
                    }
                }
        }
        .buttonStyle(.plain)
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
        .foregroundStyle(isSelected ? Color.accentColor : .primary)
    }

    // MARK: - Detail

    @ViewBuilder
    private var detailColumn: some View {
        NavigationStack {
            iPadTabContent(store: store, tab: store.selectedTab)
                .padding(.horizontal, 24)
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

// MARK: - Helpers

private extension View {
    /// Forces the TabView to use bottom tabs (iPhone style) on iPad in
    /// iOS 18+, instead of the new sidebar-adaptable style that renders
    /// top pills + a reserved sidebar gutter. No-op on iOS 17.
    @ViewBuilder
    func forceBottomTabBarOnIPad() -> some View {
        if #available(iOS 18.0, *) {
            self.tabViewStyle(.tabBarOnly)
        } else {
            self
        }
    }

    /// Centers the view within the available width, capped at `maxWidth`.
    /// No background — the app-wide PepinilloLiquidBackground in AppView
    /// shows through the gutters and the content area uniformly.
    func constrainedWidth(_ maxWidth: CGFloat) -> some View {
        self
            .frame(maxWidth: maxWidth)
            .frame(maxWidth: .infinity)
    }
}

// MARK: - Shared tab content router (iPad portrait + landscape)

struct iPadTabContent: View {
    @Bindable var store: StoreOf<AppFeature>
    let tab: AppFeature.Tab

    var body: some View {
        Group {
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
        .background(Color.clear)
    }
}
