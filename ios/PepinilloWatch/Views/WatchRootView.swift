// WatchRootView.swift
// Pepinillo — Deep Work Companion for Apple
//
// Root view for the watchOS app. Vertical-paged TabView with three screens:
// Timer (top), Tasks (middle), Dashboard (bottom).

import SwiftUI
import ComposableArchitecture

struct WatchRootView: View {
    @Bindable var store: StoreOf<WatchAppFeature>

    var body: some View {
        TabView(selection: $store.selectedTab.sending(\.tabSelected)) {
            WatchTimerView(
                store: store.scope(state: \.timer, action: \.timer)
            )
            .tag(WatchAppFeature.WatchTab.timer)

            WatchTasksView(
                store: store.scope(state: \.tasks, action: \.tasks),
                linkedTaskID: store.timer.linkedTaskID.flatMap { UUID(uuidString: $0) }
            )
            .tag(WatchAppFeature.WatchTab.tasks)

            WatchDashboardView(
                store: store.scope(state: \.dashboard, action: \.dashboard)
            )
            .tag(WatchAppFeature.WatchTab.dashboard)
        }
        .tabViewStyle(.verticalPage)
        .onAppear { store.send(.onAppear) }
    }
}
