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

    /// Sidebar selection model (Reminders-style): the Plan filters live as
    /// section rows in the sidebar instead of a toolbar menu. The shared
    /// `selectedPlanFilter` reducer state stays the single source of truth.
    private enum SidebarSelection: Hashable {
        case focus
        case plan(MacPlanFilter)
        case dashboard
    }

    private var sidebarSelection: Binding<SidebarSelection?> {
        Binding(
            get: {
                switch store.selectedTab {
                case .focus: return .focus
                case .plan: return .plan(MacPlanFilter(shared: store.tasks.selectedPlanFilter))
                case .dashboard: return .dashboard
                case .account: return nil
                }
            },
            set: { selection in
                guard let selection else { return }
                switch selection {
                case .focus:
                    store.send(.tabSelected(.focus))
                case .plan(let filter):
                    store.send(.tabSelected(.plan))
                    store.send(.tasks(.planFilterSelected(filter.sharedFilter)))
                case .dashboard:
                    store.send(.tabSelected(.dashboard))
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
        .tint(Color.accentColor)
    }

    private var sidebar: some View {
        List(selection: sidebarSelection) {
            // Explicit sections: a bare row following the Plan section renders
            // visually attached to it — Dashboard is a sibling of Plan, never
            // a member of it.
            Section {
                sidebarRow(
                    String(localized: "Focus"),
                    systemImage: AppFeature.Tab.focus.macSystemImage,
                    tag: .focus,
                    isSelected: store.selectedTab == .focus
                )
            }

            Section(String(localized: "Plan")) {
                ForEach(MacPlanFilter.allCases) { filter in
                    sidebarRow(
                        filter.title,
                        systemImage: filter.systemImage,
                        tag: .plan(filter),
                        isSelected: store.selectedTab == .plan
                            && store.tasks.selectedPlanFilter == filter.sharedFilter
                    )
                }
            }

            Section {
                sidebarRow(
                    String(localized: "Dashboard"),
                    systemImage: AppFeature.Tab.dashboard.macSystemImage,
                    tag: .dashboard,
                    isSelected: store.selectedTab == .dashboard
                )
            }
        }
        .listStyle(.sidebar)
        .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 280)
        .navigationTitle("Pepinillo")
        .safeAreaInset(edge: .bottom) {
            sidebarFooter
        }
    }

    /// Podcasts/Music sidebar treatment: selected row = filled accent capsule
    /// filling the row height (content vertically centered) with white
    /// icon+label; unselected rows carry the accent on their icons with
    /// primary text. Fixed row height so the capsule aligns edge-to-edge
    /// vertically with neighboring rows.
    private func sidebarRow(
        _ title: String,
        systemImage: String,
        tag: SidebarSelection,
        isSelected: Bool
    ) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(isSelected ? Color.white : Color.accentColor)
                .frame(width: 22)
                .accessibilityHidden(true)

            Text(title)
                .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? Color.white : Color.primary)
                .lineLimit(1)
        }
        .padding(.horizontal, 9)
        .frame(height: 26, alignment: .leading)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            if isSelected {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.accentColor)
                    .padding(.vertical, 1)
            }
        }
        .contentShape(Rectangle())
        .tag(tag)
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets(top: 0, leading: 8, bottom: 0, trailing: 8))
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
                .background(Circle().fill(Color.accentColor))
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
        // Matches the iOS tab name; frees "Today" for the sidebar task list.
        case .dashboard: return String(localized: "Dashboard")
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
