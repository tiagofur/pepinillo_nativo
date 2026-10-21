// MacAppView.swift
// Pepinillo — native macOS root view

import SwiftUI
import ComposableArchitecture

struct MacAppView: View {
    @Bindable var store: StoreOf<AppFeature>

    private var activeTheme: AppTheme {
        AppTheme.named(store.settings.themeName)
    }

    private var preferredColorScheme: ColorScheme? {
        switch store.settings.appearanceMode {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }

    var body: some View {
        rootContent
            .environment(\.appTheme, activeTheme)
            .preferredColorScheme(preferredColorScheme)
            .onOpenURL { url in
                store.send(.appURLReceived(url))
            }
            .focusedValue(\.appStore, store)
            .modifier(MacAppSheetPresenter(store: store))
            .overlay {
                celebrationOverlay
            }
            .conditionalAnimation(.easeInOut(duration: 0.3), value: store.pendingCelebration)
    }

    @ViewBuilder
    private var rootContent: some View {
        Group {
            if !store.hasCompletedOnboarding {
                OnboardingView(onComplete: completeOnboarding)
            } else {
                mainAppContent
            }
        }
    }

    private var mainAppContent: some View {
        NavigationSplitView {
            List(selection: selectedTabBinding) {
                ForEach(AppFeature.Tab.allCases, id: \.self) { tab in
                    Label(tab.title, systemImage: tab.systemImage)
                        .tag(tab)
                }
            }
            .navigationTitle("Pepinillo")
            .frame(minWidth: 180)
        } detail: {
            selectedContent
                .frame(minWidth: 720, minHeight: 560)
        }
        .tint(activeTheme.color(for: .pomodoro))
    }

    private var selectedTabBinding: Binding<AppFeature.Tab?> {
        Binding(
            get: { store.selectedTab },
            set: { tab in
                if let tab {
                    store.send(.tabSelected(tab))
                }
            }
        )
    }

    private func completeOnboarding(_ selectedMode: FocusMode) {
        store.send(.onboardingCompletedWithMode(selectedMode))
    }

    @ViewBuilder
    private func calendarSheet(_ calendarStore: StoreOf<CalendarFeature>) -> some View {
        NavigationStack {
            CalendarView(store: calendarStore)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(String(localized: "Done"), action: dismissCalendarSheet)
                    }
                }
        }
        .frame(minWidth: 640, minHeight: 560)
    }

    private func dismissCalendarSheet() {
        store.send(.calendarSheetDismissed)
    }

    @ViewBuilder
    private var celebrationOverlay: some View {
        if let milestone = store.pendingCelebration {
            CelebrationView(milestone: milestone, onDismiss: dismissCelebration)
                .transition(.opacity)
                .zIndex(100)
        }
    }

    private func dismissCelebration() {
        store.send(.celebrationDismissed)
    }

    private var paywallPresentation: Binding<Bool> {
        Binding(
            get: { store.focus.showPaywall },
            set: { isPresented in
                if !isPresented {
                    store.send(.focus(.paywallDismissed))
                }
            }
        )
    }

    private var paywallSheet: some View {
        PaywallView(
            store: store.scope(state: \.paywall, action: \.paywall)
        )
        .frame(minWidth: 520, minHeight: 640)
    }

    private func weeklyReviewSheet(_ weeklyStore: StoreOf<WeeklyReviewFeature>) -> some View {
        WeeklyReviewView(
            store: weeklyStore,
            isProUser: store.subscriptionState.isPro,
            analyticsStore: store.scope(state: \.analytics, action: \.analytics)
        )
        .frame(minWidth: 720, minHeight: 620)
    }

    private func monthlyReviewSheet(_ monthlyStore: StoreOf<MonthlyReviewFeature>) -> some View {
        MonthlyReviewView(
            store: monthlyStore,
            isProUser: store.subscriptionState.isPro,
            analyticsStore: store.scope(state: \.analytics, action: \.analytics)
        )
        .frame(minWidth: 720, minHeight: 620)
    }

    private func aiReportSheet(_ aiStore: StoreOf<AIReportFeature>) -> some View {
        AIReportView(store: aiStore)
            .frame(minWidth: 700, minHeight: 620)
    }

    private func authSheet(_ authStore: StoreOf<AuthFeature>) -> some View {
        NavigationStack {
            AuthView(
                store: authStore,
                onAppleSignIn: { info in
                    store.send(.signInWithAppleSucceeded(info))
                },
                onAppleSignInFailed: { cancelled in
                    store.send(.signInWithAppleFailed(wasUserCancelled: cancelled))
                }
            )
        }
        .frame(minWidth: 520, minHeight: 640)
        .interactiveDismissDisabled(
            authStore.isLoading || authStore.isSyncing || authStore.showMergeDialog
        )
    }

    private func profileSheet(_ profileStore: StoreOf<ProfileFeature>) -> some View {
        NavigationStack {
            ProfileView(store: profileStore)
        }
        .frame(minWidth: 560, minHeight: 640)
    }

    private func emailVerificationSheet(_ verificationStore: StoreOf<EmailVerificationFeature>) -> some View {
        NavigationStack {
            EmailVerificationView(store: verificationStore)
                .navigationTitle(String(localized: "Verify Email"))
        }
        .frame(minWidth: 520, minHeight: 520)
        .interactiveDismissDisabled()
    }

    @ViewBuilder
    private var selectedContent: some View {
        switch store.selectedTab {
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

        case .plan:
            PlanSplitView(store: store.scope(state: \.tasks, action: \.tasks))
                .systemContentBackground(grouped: true)

        case .dashboard:
            NavigationStack {
                DashboardView(store: store.scope(state: \.analytics, action: \.analytics))
            }
            .systemContentBackground(grouped: true)

        case .account:
            AccountView(store: store)
                .systemContentBackground(grouped: true)
        }
    }
}

private struct MacAppSheetPresenter: ViewModifier {
    @Bindable var store: StoreOf<AppFeature>

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: paywallPresentation) {
                paywallSheet
            }
            .sheet(item: $store.scope(state: \.calendar, action: \.calendar)) { calendarStore in
                calendarSheet(calendarStore)
            }
            .sheet(item: $store.scope(state: \.analytics.weeklyReview, action: \.analytics.weeklyReview)) { weeklyStore in
                weeklyReviewSheet(weeklyStore)
            }
            .sheet(item: $store.scope(state: \.analytics.monthlyReview, action: \.analytics.monthlyReview)) { monthlyStore in
                monthlyReviewSheet(monthlyStore)
            }
            .sheet(item: $store.scope(state: \.analytics.aiReport, action: \.analytics.aiReport)) { aiStore in
                aiReportSheet(aiStore)
            }
            .sheet(item: $store.scope(state: \.auth, action: \.auth)) { authStore in
                authSheet(authStore)
            }
            .sheet(item: $store.scope(state: \.profile, action: \.profile)) { profileStore in
                profileSheet(profileStore)
            }
            .sheet(item: $store.scope(state: \.emailVerification, action: \.emailVerification)) { verificationStore in
                emailVerificationSheet(verificationStore)
            }
    }

    private var paywallPresentation: Binding<Bool> {
        Binding(
            get: { store.focus.showPaywall },
            set: { isPresented in
                if !isPresented {
                    store.send(.focus(.paywallDismissed))
                }
            }
        )
    }

    private var paywallSheet: some View {
        PaywallView(
            store: store.scope(state: \.paywall, action: \.paywall)
        )
        .frame(minWidth: 520, minHeight: 640)
    }

    @ViewBuilder
    private func calendarSheet(_ calendarStore: StoreOf<CalendarFeature>) -> some View {
        NavigationStack {
            CalendarView(store: calendarStore)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(String(localized: "Done"), action: dismissCalendarSheet)
                    }
                }
        }
        .frame(minWidth: 640, minHeight: 560)
    }

    private func dismissCalendarSheet() {
        store.send(.calendarSheetDismissed)
    }

    private func weeklyReviewSheet(_ weeklyStore: StoreOf<WeeklyReviewFeature>) -> some View {
        WeeklyReviewView(
            store: weeklyStore,
            isProUser: store.subscriptionState.isPro,
            analyticsStore: store.scope(state: \.analytics, action: \.analytics)
        )
        .frame(minWidth: 720, minHeight: 620)
    }

    private func monthlyReviewSheet(_ monthlyStore: StoreOf<MonthlyReviewFeature>) -> some View {
        MonthlyReviewView(
            store: monthlyStore,
            isProUser: store.subscriptionState.isPro,
            analyticsStore: store.scope(state: \.analytics, action: \.analytics)
        )
        .frame(minWidth: 720, minHeight: 620)
    }

    private func aiReportSheet(_ aiStore: StoreOf<AIReportFeature>) -> some View {
        AIReportView(store: aiStore)
            .frame(minWidth: 700, minHeight: 620)
    }

    private func authSheet(_ authStore: StoreOf<AuthFeature>) -> some View {
        NavigationStack {
            AuthView(
                store: authStore,
                onAppleSignIn: { info in
                    store.send(.signInWithAppleSucceeded(info))
                },
                onAppleSignInFailed: { cancelled in
                    store.send(.signInWithAppleFailed(wasUserCancelled: cancelled))
                }
            )
        }
        .frame(minWidth: 520, minHeight: 640)
        .interactiveDismissDisabled(
            authStore.isLoading || authStore.isSyncing || authStore.showMergeDialog
        )
    }

    private func profileSheet(_ profileStore: StoreOf<ProfileFeature>) -> some View {
        NavigationStack {
            ProfileView(store: profileStore)
        }
        .frame(minWidth: 560, minHeight: 640)
    }

    private func emailVerificationSheet(_ verificationStore: StoreOf<EmailVerificationFeature>) -> some View {
        NavigationStack {
            EmailVerificationView(store: verificationStore)
                .navigationTitle(String(localized: "Verify Email"))
        }
        .frame(minWidth: 520, minHeight: 520)
        .interactiveDismissDisabled()
    }
}
