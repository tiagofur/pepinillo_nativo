// iPadSplitView.swift
// Pepinillo — Deep Work Companion for Apple
//
// Adaptive iPad / Mac layouts. Two concrete variants chosen by
// AppView via GeometryReader (horizontalSizeClass alone cannot
// differentiate iPad portrait from landscape — both report .regular):
//
//   • iPadLandscapeLayout — NavigationSplitView (sidebar + detail).
//     Sidebar exposes the same 4 tabs as the iPhone TabView.
//
//   • iPadPortraitLayout — Top menu above the content. Same 4 tabs
//     as a row of buttons at the top. Each tab has its OWN
//     NavigationStack so the top menu never moves because of
//     inner nav bars.

import SwiftUI
import ComposableArchitecture

// MARK: - iPad Landscape: Sidebar + Detail

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

// MARK: - iPad Portrait: Top menu + content

/// Top menu (fixed, outside any NavigationStack) + per-tab independent
/// NavigationStacks. Keeping the top menu outside prevents it from being
/// pushed around by each inner view's nav bar. Each tab has its own
/// NavigationStack so navigation state is independent per tab and
/// switching tabs always works cleanly.
struct iPadPortraitLayout: View {
    @Bindable var store: StoreOf<AppFeature>

    var body: some View {
        VStack(spacing: 0) {
            topTabBar

            Divider()

            Group {
                switch store.selectedTab {
                case .focus:
                    NavigationStack {
                        FocusView(store: store.scope(state: \.focus, action: \.focus))
                    }

                case .plan:
                    NavigationStack {
                        PlanView(store: store.scope(state: \.tasks, action: \.tasks))
                    }

                case .dashboard:
                    NavigationStack {
                        DashboardView(store: store.scope(state: \.analytics, action: \.analytics))
                    }

                case .account:
                    AccountView(store: store)
                }
            }
        }
    }

    // MARK: - Top Tab Bar

    private var topTabBar: some View {
        HStack(spacing: 8) {
            ForEach(AppFeature.Tab.allCases, id: \.self) { tab in
                tabButton(tab)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private func tabButton(_ tab: AppFeature.Tab) -> some View {
        let isSelected = store.selectedTab == tab
        return Button {
            store.send(.tabSelected(tab))
        } label: {
            HStack(spacing: 8) {
                Image(systemName: tab.systemImage)
                    .font(.system(size: 16, weight: .medium))
                Text(tab.title)
                    .font(.subheadline.weight(isSelected ? .semibold : .regular))
            }
            .foregroundStyle(isSelected ? Color.accentColor : .secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                isSelected ? Color.accentColor.opacity(0.15) : Color.clear,
                in: RoundedRectangle(cornerRadius: 10)
            )
            .contentShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tab.title)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
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
