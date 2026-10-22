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

    /// v1 has no account surface on macOS. If shared state still points at it,
    /// fall back to Focus instead of rendering an iOS account screen.
    private var effectiveTab: AppFeature.Tab {
        store.selectedTab == .account ? .focus : store.selectedTab
    }

    private var selectedSectionBinding: Binding<AppFeature.Tab?> {
        Binding(
            get: { effectiveTab },
            set: { tab in
                if let tab {
                    store.send(.tabSelected(tab))
                }
            }
        )
    }

    var body: some View {
        rootContent
            .environment(\.appTheme, activeTheme)
            .preferredColorScheme(preferredColorScheme)
            .onOpenURL { url in
                store.send(.appURLReceived(url))
            }
            .focusedValue(\.appStore, store)
            .sheet(isPresented: paywallPresentation) {
                paywallSheet
            }
            .overlay {
                celebrationOverlay
            }
            .conditionalAnimation(.easeInOut(duration: 0.3), value: store.pendingCelebration)
            .onAppear(perform: normalizeSelection)
            .onChange(of: store.selectedTab) { _, tab in
                if tab == .account {
                    store.send(.tabSelected(.focus))
                } else {
                    persistSelection(tab)
                }
            }
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
            sidebar
        } detail: {
            selectedContent
                .frame(minWidth: 760, minHeight: 640)
                .navigationTitle(effectiveTab.macTitle)
        }
        .frame(minWidth: 960, minHeight: 640)
        .tint(activeTheme.color(for: .pomodoro))
    }

    private var sidebar: some View {
        List(selection: selectedSectionBinding) {
            ForEach(AppFeature.Tab.macSidebarSections, id: \.self) { tab in
                Label {
                    Text(tab.macTitle)
                } icon: {
                    Image(systemName: tab.macSystemImage)
                }
                .tag(tab)
            }
        }
        .listStyle(.sidebar)
        .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 280)
        .navigationTitle("Pepinillo")
        .safeAreaInset(edge: .bottom) {
            sidebarFooter
        }
    }

    private var sidebarFooter: some View {
        VStack(alignment: .leading, spacing: 2) {
            if store.subscriptionState.isPro {
                Label("Pepinillo+", systemImage: "sparkles")
            } else {
                Text("Pepinillo \(appVersion)")
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    @ViewBuilder
    private var selectedContent: some View {
        switch effectiveTab {
        case .focus:
            focusContent
        case .plan:
            planContent
        case .dashboard:
            todayContent
        case .account:
            focusContent
        }
    }

    private var focusContent: some View {
        MacFocusView(
            store: store.scope(state: \.focus, action: \.focus),
            streakDays: store.analytics.currentStreakDays,
            sessionsToday: store.analytics.todaySessions,
            totalFocusMinutesToday: store.analytics.todayFocusMinutes
        )
        .withAmbientBackground()
    }

    private var planContent: some View {
        MacPlanView(store: store.scope(state: \.tasks, action: \.tasks))
            .systemContentBackground(grouped: false)
    }

    private var todayContent: some View {
        MacTodayView(
            analytics: store.analytics,
            tasks: store.tasks,
            onStartFocus: { task in
                store.send(.tabSelected(.focus))
                guard !store.focus.isRunning else { return }
                if let task {
                    store.send(.focus(.linkTask(task.id, task.title, task.energyLevel.icon)))
                }
                store.send(.focus(.startTapped()))
            },
            onOpenPlan: {
                store.send(.tabSelected(.plan))
            },
            onRefresh: {
                store.send(.analytics(.refresh))
            }
        )
        .onAppear {
            store.send(.analytics(.onAppear))
        }
    }

    private func completeOnboarding(_ selectedMode: FocusMode) {
        store.send(.onboardingCompletedWithMode(selectedMode))
    }

    private func normalizeSelection() {
        guard store.selectedTab == .account else { return }
        store.send(.tabSelected(.focus))
    }

    private func persistSelection(_ tab: AppFeature.Tab) {
        guard tab != .account else { return }
        UserDefaults.standard.set(tab.rawValue, forKey: MacAppStorageKeys.selectedSection)
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
}

extension AppFeature.Tab {
    static let macSidebarSections: [AppFeature.Tab] = [.focus, .plan, .dashboard]

    var macTitle: String {
        switch self {
        case .focus: return String(localized: "Focus")
        case .plan: return String(localized: "Plan")
        case .dashboard: return String(localized: "Today")
        case .account: return String(localized: "Account")
        }
    }

    var macSystemImage: String {
        switch self {
        case .focus: return "timer"
        case .plan: return "checklist"
        case .dashboard: return "chart.bar"
        case .account: return "person.crop.circle"
        }
    }
}
