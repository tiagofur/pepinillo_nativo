// MacAppView.swift
// Pepinillo — native macOS root view

import SwiftUI
import ComposableArchitecture

struct MacAppView: View {
    @Bindable var store: StoreOf<AppFeature>

    @Environment(\.appTheme) private var theme
    @Environment(\.openSettings) private var openSettings

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

    private var selectedSectionBinding: Binding<AppFeature.Tab?> {
        Binding(
            get: { store.selectedTab },
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
            .onChange(of: store.selectedTab) { _, tab in
                persistSelection(tab)
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
                .navigationTitle(store.selectedTab.macTitle)
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

    /// Bottom-of-sidebar account row + settings gear, the common modern Mac
    /// pattern for secondary surfaces. The gear opens the standard Settings
    /// scene (Cmd+,); the row selects the Account section.
    private var sidebarFooter: some View {
        HStack(spacing: 8) {
            Button {
                store.send(.tabSelected(.account))
            } label: {
                HStack(spacing: 8) {
                    accountAvatar
                    VStack(alignment: .leading, spacing: 1) {
                        Text(footerTitle)
                            .font(.callout.weight(.medium))
                            .lineLimit(1)
                        if isSignedIn, let email = store.userEmail {
                            Text(email)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .background {
                if store.selectedTab == .account {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(.quaternary)
                }
            }

            Button {
                openSettings()
            } label: {
                Image(systemName: "gearshape")
                    .font(.body)
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help(String(localized: "Settings"))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(.bar)
    }

    private var isSignedIn: Bool {
        store.cachedUser != nil || store.userEmail != nil
    }

    private var footerTitle: String {
        if isSignedIn, let name = store.displayName, !name.isEmpty {
            return name
        }
        if let email = store.userEmail {
            return email
        }
        return String(localized: "Account")
    }

    @ViewBuilder
    private var accountAvatar: some View {
        if isSignedIn {
            let initial = String((store.displayName ?? store.userEmail ?? "P").prefix(1)).uppercased()
            Text(initial)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 26, height: 26)
                .background(Circle().fill(theme.color(for: .pomodoro)))
        } else {
            Image(systemName: "person.crop.circle")
                .font(.title3)
                .foregroundStyle(.secondary)
                .frame(width: 26, height: 26)
        }
    }

    @ViewBuilder
    private var selectedContent: some View {
        switch store.selectedTab {
        case .focus:
            focusContent
        case .plan:
            planContent
        case .dashboard:
            todayContent
        case .account:
            MacAccountView(store: store)
                .systemContentBackground(grouped: true)
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

extension FocusMode {
    /// The macOS design contract uses "Time Block"; the shared display name
    /// shortens it to "Block" for compact iOS surfaces.
    var macDisplayName: String {
        self == .timeBlock ? String(localized: "Time Block") : displayName
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
