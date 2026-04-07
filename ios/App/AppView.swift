// AppView.swift
// Pepinillo — Deep Work Companion for Apple
//
// Root view routing:
// - Not onboarded → OnboardingView
// - iPad / Mac (.regular width) → iPadSplitView (three-column NavigationSplitView)
// - iPhone → TabView (3 tabs) + DrawerOverlay
//
// Hosts the celebration overlay, paywall sheet, auth sheet, and profile sheet at root level.

import SwiftUI
import ComposableArchitecture

struct AppView: View {
    @Bindable var store: StoreOf<AppFeature>
    @Environment(\.horizontalSizeClass) private var sizeClass

    private var activeTheme: AppTheme {
        AppTheme.named(store.settings.themeName)
    }

    private var preferredColorScheme: ColorScheme? {
        switch store.settings.appearanceMode {
        case "light": return .light
        case "dark": return .dark
        default: return nil  // follows system
        }
    }

    var body: some View {
        Group {
            if !store.hasCompletedOnboarding {
                OnboardingView { selectedMode in
                    store.send(.onboardingCompletedWithMode(selectedMode))
                }
            } else if sizeClass == .regular {
                iPadSplitView(store: store)
            } else {
                iPhoneLayout
            }
        }
        .environment(\.appTheme, activeTheme)
        .preferredColorScheme(preferredColorScheme)
        .onAppear {
            store.send(.appLaunched)
        }
        // Paywall sheet
        .sheet(
            isPresented: Binding(
                get: { store.focus.showPaywall },
                set: { if !$0 { store.send(.focus(.paywallDismissed)) } }
            )
        ) {
            PaywallView(
                store: Store(initialState: PaywallFeature.State()) {
                    PaywallFeature()
                } withDependencies: { deps in
                    deps.dismiss = DismissEffect { store.send(.focus(.paywallDismissed)) }
                }
            )
        }
        // Settings sheet (from drawer)
        .sheet(
            isPresented: Binding(
                get: { store.isSettingsPresented },
                set: { if !$0 { store.send(.settingsSheetDismissed) } }
            )
        ) {
            NavigationStack {
                SettingsView(store: store.scope(state: \.settings, action: \.settings))
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button(String(localized: "Done")) {
                                store.send(.settingsSheetDismissed)
                            }
                        }
                    }
            }
        }
        // Calendar sheet (from drawer)
        .sheet(item: $store.scope(state: \.calendar, action: \.calendar)) { calendarStore in
            NavigationStack {
                CalendarView(store: calendarStore)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button(String(localized: "Done")) {
                                store.send(.calendarSheetDismissed)
                            }
                        }
                    }
            }
        }
        // Weekly Review sheet (from drawer)
        .sheet(
            item: $store.scope(state: \.analytics.weeklyReview, action: \.analytics.weeklyReview)
        ) { weeklyStore in
            WeeklyReviewView(store: weeklyStore)
                .iPadSheetSizing()
        }
        // Auth sheet
        .sheet(item: $store.scope(state: \.auth, action: \.auth)) { authStore in
            NavigationStack {
                AuthView(store: authStore)
            }
            .presentationDetents([.large])
        }
        // Profile sheet
        .sheet(item: $store.scope(state: \.profile, action: \.profile)) { profileStore in
            NavigationStack {
                ProfileView(store: profileStore)
            }
            .presentationDetents([.large])
        }
        // Celebration overlay
        .overlay {
            if let milestone = store.pendingCelebration {
                CelebrationView(milestone: milestone) {
                    store.send(.celebrationDismissed)
                }
                .transition(.opacity)
                .zIndex(100)
            }
        }
        .conditionalAnimation(.easeInOut(duration: 0.3), value: store.pendingCelebration)
        // MARK: - Handoff: Donate current activity
        .userActivity(HandoffActivity.focusSession) { activity in
            let modeID = (store.focus.activeMode ?? store.focus.selectedMode).rawValue
            activity.title = store.focus.isRunning
                ? "Focus Session — \(modeID)"
                : "Ready to Focus"
            activity.isEligibleForHandoff = true
            activity.userInfo = [
                HandoffActivity.Key.modeID: modeID,
                HandoffActivity.Key.isRunning: store.focus.isRunning,
            ]
        }
        // MARK: - Handoff: Receive from another device
        .onContinueUserActivity(HandoffActivity.focusSession) { activity in
            guard let info = activity.userInfo,
                  let modeID = info[HandoffActivity.Key.modeID] as? String else { return }
            let isRunning = info[HandoffActivity.Key.isRunning] as? Bool ?? false
            let taskTitle = info[HandoffActivity.Key.taskTitle] as? String
            store.send(.handoffFocusReceived(modeID: modeID, isRunning: isRunning, taskTitle: taskTitle))
        }
        .onContinueUserActivity(HandoffActivity.viewAnalytics) { _ in
            store.send(.handoffAnalyticsReceived)
        }
    }

    // MARK: - iPhone Layout

    private var iPhoneLayout: some View {
        ZStack {
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
            .focusedValue(\.appStore, store)

            // Edge swipe to open drawer
            if !store.isDrawerOpen {
                HStack {
                    Color.clear
                        .frame(width: 20)
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 30)
                                .onEnded { value in
                                    if value.translation.width > 30 && abs(value.translation.height) < 80 {
                                        store.send(.drawerOpened, animation: .easeInOut(duration: 0.28))
                                    }
                                }
                        )
                    Spacer()
                }
                .ignoresSafeArea()
            }

            // Drawer overlay (sits on top of TabView)
            DrawerOverlayView(store: store)
        }
    }

    // MARK: - Tab Content Router

    @ViewBuilder
    private func tabContent(for tab: AppFeature.Tab) -> some View {
        switch tab {
        case .focus:
            NavigationStack {
                FocusView(store: store.scope(state: \.focus, action: \.focus))
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            AvatarNavButton {
                                store.send(.drawerOpened, animation: .easeInOut(duration: 0.28))
                            }
                        }
                    }
            }

        case .tasks:
            NavigationStack {
                TaskListView(store: store.scope(state: \.tasks, action: \.tasks))
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            AvatarNavButton {
                                store.send(.drawerOpened, animation: .easeInOut(duration: 0.28))
                            }
                        }
                    }
            }

        case .analytics:
            NavigationStack {
                AnalyticsView(store: store.scope(state: \.analytics, action: \.analytics))
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            AvatarNavButton {
                                store.send(.drawerOpened, animation: .easeInOut(duration: 0.28))
                            }
                        }
                    }
            }
        }
    }
}

// MARK: - FocusedValue key for keyboard shortcut access

private struct AppStoreKey: FocusedValueKey {
    typealias Value = StoreOf<AppFeature>
}

extension FocusedValues {
    var appStore: StoreOf<AppFeature>? {
        get { self[AppStoreKey.self] }
        set { self[AppStoreKey.self] = newValue }
    }
}
