// AppView.swift
// Pepinillo — Deep Work Companion for Apple
//
// Root view routing:
// - Not onboarded → OnboardingView
// - iOS 18+ (iPad & iPhone) → TabView(.sidebarAdaptable)
//   iPad: floating top pill + on-demand sidebar (Apple-native iPadOS 18+ pattern)
//   iPhone: bottom tabs (unchanged)
// - iOS 17 fallback → iPhoneLayout (TabView with bottom tabs, all devices)
//
// Hosts the celebration overlay, paywall sheet, auth sheet, and profile sheet at root level.

import SwiftUI
import ComposableArchitecture

struct AppView: View {
    @Bindable var store: StoreOf<AppFeature>

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
        ZStack {
            PepinilloLiquidBackground()
                .ignoresSafeArea()

            Group {
                if !store.hasCompletedOnboarding {
                    OnboardingView { selectedMode in
                        store.send(.onboardingCompletedWithMode(selectedMode))
                    }
                } else if #available(iOS 18.0, *) {
                    adaptableTabView
                } else {
                    iPhoneLayout
                }
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
        // Calendar sheet
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
        // Weekly Review sheet
        .sheet(
            item: $store.scope(state: \.analytics.weeklyReview, action: \.analytics.weeklyReview)
        ) { weeklyStore in
            WeeklyReviewView(store: weeklyStore, isProUser: store.subscriptionState.isPro, analyticsStore: store.scope(state: \.analytics, action: \.analytics))
                .iPadSheetSizing()
        }
        // Monthly Review sheet
        .sheet(
            item: $store.scope(state: \.analytics.monthlyReview, action: \.analytics.monthlyReview)
        ) { monthlyStore in
            MonthlyReviewView(store: monthlyStore, isProUser: store.subscriptionState.isPro, analyticsStore: store.scope(state: \.analytics, action: \.analytics))
                .iPadSheetSizing()
        }
        // AI Report sheet
        .sheet(
            item: $store.scope(state: \.analytics.aiReport, action: \.analytics.aiReport)
        ) { aiStore in
            AIReportView(store: aiStore)
                .iPadSheetSizing()
        }
        // Auth sheet
        .sheet(item: $store.scope(state: \.auth, action: \.auth)) { authStore in
            NavigationStack {
                AuthView(
                    store: authStore,
                    onAppleSignIn: { info in
                        store.send(.signInWithAppleSucceeded(info))
                    },
                    onAppleSignInFailed: {
                        store.send(.signInWithAppleFailed)
                    }
                )
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
        // Email verification sheet (shown after email/password login when not yet verified)
        .sheet(item: $store.scope(state: \.emailVerification, action: \.emailVerification)) { verificationStore in
            NavigationStack {
                EmailVerificationView(store: verificationStore)
                    .navigationTitle(String(localized: "Verify Email"))
                    .navigationBarTitleDisplayMode(.inline)
            }
            .presentationDetents([.large])
            .interactiveDismissDisabled()
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

    // MARK: - iOS 18+ Adaptable TabView
    // On iPad: floating top pill + on-demand sidebar (sidebarAdaptable).
    // On iPhone: bottom tabs — same as before.

    @available(iOS 18.0, *)
    private var adaptableTabView: some View {
        TabView(selection: Binding(
            get: { store.selectedTab },
            set: { store.send(.tabSelected($0)) }
        )) {
            Tab(
                String(localized: "Focus"),
                systemImage: AppFeature.Tab.focus.systemImage,
                value: AppFeature.Tab.focus
            ) {
                NavigationStack {
                    FocusView(
                        store: store.scope(state: \.focus, action: \.focus),
                        streakDays: store.analytics.currentStreakDays,
                        sessionsToday: store.analytics.sessionsCompleted,
                        totalFocusMinutesToday: store.analytics.totalFocusMinutes
                    )
                }
            }

            Tab(
                String(localized: "Plan"),
                systemImage: AppFeature.Tab.plan.systemImage,
                value: AppFeature.Tab.plan
            ) {
                PlanSplitView(store: store.scope(state: \.tasks, action: \.tasks))
            }

            Tab(
                String(localized: "Dashboard"),
                systemImage: AppFeature.Tab.dashboard.systemImage,
                value: AppFeature.Tab.dashboard
            ) {
                NavigationStack {
                    DashboardView(store: store.scope(state: \.analytics, action: \.analytics))
                }
            }

            Tab(
                String(localized: "More"),
                systemImage: AppFeature.Tab.account.systemImage,
                value: AppFeature.Tab.account
            ) {
                AccountView(store: store)
            }
        }
        .tabViewStyle(.sidebarAdaptable)
        .focusedValue(\.appStore, store)
    }

    // MARK: - iOS 17 Fallback Layout

    private var iPhoneLayout: some View {
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
    }

    // MARK: - Tab Content Router (iOS 17 fallback)

    @ViewBuilder
    private func tabContent(for tab: AppFeature.Tab) -> some View {
        switch tab {
        case .focus:
            NavigationStack {
                FocusView(
                    store: store.scope(state: \.focus, action: \.focus),
                    streakDays: store.analytics.currentStreakDays,
                    sessionsToday: store.analytics.sessionsCompleted,
                    totalFocusMinutesToday: store.analytics.totalFocusMinutes
                )
            }

        case .plan:
            PlanSplitView(store: store.scope(state: \.tasks, action: \.tasks))

        case .dashboard:
            NavigationStack {
                DashboardView(store: store.scope(state: \.analytics, action: \.analytics))
            }

        case .account:
            AccountView(store: store)
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
