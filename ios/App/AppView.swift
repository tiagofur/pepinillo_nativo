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
        .overlay(alignment: .top) {
            if store.isOffline {
                OfflineBanner()
                    .padding(.top, 4)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(MotionTokens.snappy, value: store.isOffline)
        .environment(\.appTheme, activeTheme)
        .preferredColorScheme(preferredColorScheme)
        .onAppear {
            store.send(.appLaunched)
        }
        .onOpenURL { url in
            store.send(.appURLReceived(url))
        }
        // Paywall sheet
        .sheet(
            isPresented: Binding(
                get: { store.focus.showPaywall },
                set: { if !$0 { store.send(.focus(.paywallDismissed)) } }
            )
        ) {
            PaywallView(
                store: store.scope(state: \.paywall, action: \.paywall)
            )
            .pepinilloSheetStyle()
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
            .pepinilloSheetStyle()
        }
        // Weekly Review sheet
        .sheet(
            item: $store.scope(state: \.analytics.weeklyReview, action: \.analytics.weeklyReview)
        ) { weeklyStore in
            WeeklyReviewView(store: weeklyStore, isProUser: store.subscriptionState.isPro, analyticsStore: store.scope(state: \.analytics, action: \.analytics))
                .iPadSheetSizing()
                .pepinilloSheetStyle()
        }
        // Monthly Review sheet
        .sheet(
            item: $store.scope(state: \.analytics.monthlyReview, action: \.analytics.monthlyReview)
        ) { monthlyStore in
            MonthlyReviewView(store: monthlyStore, isProUser: store.subscriptionState.isPro, analyticsStore: store.scope(state: \.analytics, action: \.analytics))
                .iPadSheetSizing()
                .pepinilloSheetStyle()
        }
        // AI Report sheet
        .sheet(
            item: $store.scope(state: \.analytics.aiReport, action: \.analytics.aiReport)
        ) { aiStore in
            AIReportView(store: aiStore)
                .iPadSheetSizing()
                .pepinilloSheetStyle()
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
            .pepinilloSheetStyle()
        }
        // Profile sheet
        .sheet(item: $store.scope(state: \.profile, action: \.profile)) { profileStore in
            NavigationStack {
                ProfileView(store: profileStore)
            }
            .presentationDetents([.large])
            .pepinilloSheetStyle()
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
            .pepinilloSheetStyle()
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
                    .withAmbientBackground()
                }
                .tabContentAccent()
            }

            Tab(
                String(localized: "Plan"),
                systemImage: AppFeature.Tab.plan.systemImage,
                value: AppFeature.Tab.plan
            ) {
                PlanSplitView(store: store.scope(state: \.tasks, action: \.tasks))
                    .systemContentBackground(grouped: true)
                    .tabContentAccent()
            }

            Tab(
                String(localized: "Dashboard"),
                systemImage: AppFeature.Tab.dashboard.systemImage,
                value: AppFeature.Tab.dashboard
            ) {
                NavigationStack {
                    DashboardView(store: store.scope(state: \.analytics, action: \.analytics))
                }
                .systemContentBackground(grouped: true)
                .tabContentAccent()
            }

            Tab(
                String(localized: "More"),
                systemImage: AppFeature.Tab.account.systemImage,
                value: AppFeature.Tab.account
            ) {
                AccountView(store: store)
                    .systemContentBackground(grouped: true)
                    .tabContentAccent()
            }
        }
        .tabViewStyle(.sidebarAdaptable)
        .conditionalTabBarMinimize()
        // Monochromatic tab bar — the selected tab icon uses .primary (black in
        // light mode, white in dark) instead of AccentColor. Color lives in the
        // content (timer ring, charts, chips) and in primary CTAs, not in the
        // navigation chrome. See HIG "Tab bars": prefer monochromatic appearance
        // when the content layer is already colorful.
        .tint(.primary)
        .animation(.snappy(duration: 0.25), value: store.selectedTab)
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
        // Monochromatic tab bar (matches iOS 18+ adaptableTabView).
        .tint(.primary)
        .animation(.snappy(duration: 0.25), value: store.selectedTab)
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
                .withAmbientBackground()
            }
            .tabContentAccent()

        case .plan:
            PlanSplitView(store: store.scope(state: \.tasks, action: \.tasks))
                .systemContentBackground(grouped: true)
                .tabContentAccent()

        case .dashboard:
            NavigationStack {
                DashboardView(store: store.scope(state: \.analytics, action: \.analytics))
            }
            .systemContentBackground(grouped: true)
            .tabContentAccent()

        case .account:
            AccountView(store: store)
                .systemContentBackground(grouped: true)
                .tabContentAccent()
        }
    }
}

// MARK: - Tab content tint restoration

private extension View {
    /// Restores the AccentColor tint inside tab content.
    ///
    /// `AppView` applies `.tint(.primary)` on the TabView to give the tab bar a
    /// monochromatic look (color lives in content + CTAs, per HIG). Because
    /// `.tint` propagates via the environment, that neutral tint would also
    /// reach buttons/CTAs inside each tab. This modifier re-scopes the
    /// AccentColor (now Apple blue) so primary actions keep their color while
    /// the tab bar stays neutral.
    func tabContentAccent() -> some View {
        self.tint(Color.accentColor)
    }
}

// MARK: - Offline Banner (issue #89)

private struct OfflineBanner: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "wifi.slash")
                .font(.subheadline.weight(.semibold))
            Text(String(localized: "You're offline. Changes will sync when you reconnect."))
                .font(.caption.weight(.medium))
                .lineLimit(2)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            Capsule(style: .continuous)
                .fill(Color.orange.opacity(0.9))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(localized: "Offline. Changes will sync when you reconnect."))
    }
}
