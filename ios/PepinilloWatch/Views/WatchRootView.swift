// WatchRootView.swift
// Pepinillo — Deep Work Companion for Apple
//
// Root view for the watchOS app. Vertical-paged TabView with three screens:
// Dashboard (top), Timer (center, default), Tasks (bottom).
// Hub-and-spoke layout: Timer is always 1 swipe from either screen.

import SwiftUI
import ComposableArchitecture

struct WatchRootView: View {
    @Bindable var store: StoreOf<WatchAppFeature>

    var body: some View {
        TabView(selection: $store.selectedTab.sending(\.tabSelected)) {
            WatchDashboardView(
                store: store.scope(state: \.dashboard, action: \.dashboard)
            )
            .tag(WatchAppFeature.WatchTab.dashboard)

            WatchTimerView(
                store: store.scope(state: \.timer, action: \.timer)
            )
            .tag(WatchAppFeature.WatchTab.timer)

            WatchTasksView(
                store: store.scope(state: \.tasks, action: \.tasks),
                linkedTaskID: store.timer.linkedTaskID.flatMap { UUID(uuidString: $0) }
            )
            .tag(WatchAppFeature.WatchTab.tasks)
        }
        .tabViewStyle(.verticalPage)
        // Resolve the phone-synced theme into the view environment. Unknown names
        // fall back to classic via AppTheme.named(_:). Child views read
        // @Environment(\.appTheme) for per-mode accent colors.
        .environment(\.appTheme, AppTheme.named(store.themeName))
        .onAppear { store.send(.onAppear) }
    }
}
