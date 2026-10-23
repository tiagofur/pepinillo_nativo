// MacSettingsView.swift
// Pepinillo — native macOS settings and app-level preferences

import AppKit
import ComposableArchitecture
import ServiceManagement
import SwiftUI

/// UserDefaults keys shared by the macOS shell and settings window.
enum MacAppStorageKeys {
    static let selectedSection = "mac.selectedSection"
    static let defaultSection = "mac.defaultSection"
    /// Read raw each tick by `MacActivitySampler`; written by `MacPreferences`.
    static let topActivityEnabled = "mac.topActivityEnabled"
    /// Read raw each render by `MacStatusBarController`; written by `MacPreferences`.
    static let menuBarStatusStyle = "mac.menuBarStatusStyle"
}

// MARK: - App-level preferences

/// Preferences that belong to the macOS shell rather than the shared product
/// settings feature: launch at login and Dock visibility.
@MainActor
final class MacPreferences: ObservableObject {
    @Published private(set) var launchAtLogin: Bool
    @Published private(set) var showInDock: Bool
    @Published private(set) var defaultSection: AppFeature.Tab
    @Published private(set) var topActivityEnabled: Bool
    @Published private(set) var menuBarStatusStyle: MenuBarStatusStyle
    @Published private(set) var errorMessage: String?

    private var isApplying = false

    private enum Keys {
        static let launchAtLogin = "mac.launchAtLogin"
        static let showInDock = "mac.showInDock"
    }

    init() {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: Keys.showInDock) == nil {
            defaults.set(true, forKey: Keys.showInDock)
        }

        launchAtLogin = SMAppService.mainApp.status == .enabled
        showInDock = defaults.bool(forKey: Keys.showInDock)
        // Opt-in (design contract §18.4): no foreground sampling until the
        // user asks for it.
        topActivityEnabled = defaults.bool(forKey: MacAppStorageKeys.topActivityEnabled)
        menuBarStatusStyle = MenuBarStatusStyle.current

        let defaultRaw = defaults.string(forKey: MacAppStorageKeys.defaultSection)
        let defaultTab = defaultRaw.flatMap { AppFeature.Tab(rawValue: $0) } ?? .focus
        defaultSection = defaultTab == .account ? .focus : defaultTab

        applyDockPolicy()
    }

    func setLaunchAtLogin(_ value: Bool) {
        guard value != launchAtLogin else { return }
        launchAtLogin = value
        UserDefaults.standard.set(value, forKey: Keys.launchAtLogin)
        applyLaunchAtLogin()
    }

    func setShowInDock(_ value: Bool) {
        guard value != showInDock else { return }
        showInDock = value
        UserDefaults.standard.set(value, forKey: Keys.showInDock)
        applyDockPolicy()
    }

    func setDefaultSection(_ tab: AppFeature.Tab) {
        guard tab != .account, tab != defaultSection else { return }
        defaultSection = tab
        UserDefaults.standard.set(tab.rawValue, forKey: MacAppStorageKeys.defaultSection)
    }

    func setTopActivityEnabled(_ value: Bool) {
        guard value != topActivityEnabled else { return }
        topActivityEnabled = value
        UserDefaults.standard.set(value, forKey: MacAppStorageKeys.topActivityEnabled)
    }

    func setMenuBarStatusStyle(_ style: MenuBarStatusStyle) {
        guard style != menuBarStatusStyle else { return }
        menuBarStatusStyle = style
        UserDefaults.standard.set(style.rawValue, forKey: MacAppStorageKeys.menuBarStatusStyle)
        // The pulse only re-renders on session changes; nudge the item.
        MacStatusBarController.shared?.reloadStyle()
    }

    func applyDockPolicy() {
        NSApp.setActivationPolicy(showInDock ? .regular : .accessory)
    }

    private func applyLaunchAtLogin() {
        guard !isApplying else { return }
        isApplying = true
        defer { isApplying = false }

        do {
            if launchAtLogin {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
            // Keep the toggle aligned with the real system state.
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}

// MARK: - Settings window

struct MacSettingsView: View {
    @Bindable var store: StoreOf<AppFeature>
    @ObservedObject var preferences: MacPreferences

    private var activeTheme: AppTheme {
        AppTheme.named(store.settings.themeName)
    }

    /// Mirrors the Focus-tab mode convention: Pepinillo+ styles carry a
    /// "(Pro)" suffix and are disabled for free users.
    private func statusStyleLabel(_ style: MenuBarStatusStyle) -> String {
        let base: String = switch style {
        case .countdown: String(localized: "Countdown")
        case .timeOnly: String(localized: "Time only")
        case .iconOnly: String(localized: "Icon only")
        }
        return style.isPro && !store.subscriptionState.isPro ? "\(base) (Pro)" : base
    }

    private var preferredColorScheme: ColorScheme? {
        switch store.settings.appearanceMode {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }

    var body: some View {
        TabView {
            general
                .tabItem { Label("General", systemImage: "gearshape") }

            focus
                .tabItem { Label("Focus", systemImage: "timer") }

            notifications
                .tabItem { Label("Notifications", systemImage: "bell") }

            appearance
                .tabItem { Label("Appearance", systemImage: "paintpalette") }
        }
        .frame(width: 520, height: 460)
        .environment(\.appTheme, activeTheme)
        .preferredColorScheme(preferredColorScheme)
        .onAppear {
            store.send(.settings(.onAppear))
        }
    }

    private var general: some View {
        Form {
            Section {
                Toggle(
                    "Launch at login",
                    isOn: Binding(
                        get: { preferences.launchAtLogin },
                        set: { preferences.setLaunchAtLogin($0) }
                    )
                )

                Toggle(
                    "Show in Dock",
                    isOn: Binding(
                        get: { preferences.showInDock },
                        set: { preferences.setShowInDock($0) }
                    )
                )

                Picker(
                    "Default section",
                    selection: Binding(
                        get: { preferences.defaultSection },
                        set: { preferences.setDefaultSection($0) }
                    )
                ) {
                    ForEach(AppFeature.Tab.macSidebarSections, id: \.self) { tab in
                        Text(tab.macTitle).tag(tab)
                    }
                }
            } footer: {
                if let error = preferences.errorMessage {
                    Text(error)
                        .foregroundStyle(.red)
                } else {
                    Text("Pepinillo stays available from the menu bar when the Dock icon is hidden.")
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                Toggle(
                    "Keep screen on during sessions",
                    isOn: eventBinding(store.settings.keepScreenOn) { .keepScreenOnToggled }
                )
            } footer: {
                Text("Pepinillo keeps the display awake while a focus session runs.")
                    .foregroundStyle(.secondary)
            }

            Section {
                LabeledContent("Global shortcut", value: "⌃⌥Space")
                LabeledContent("Quick Capture", value: "⌃⌥T")
                LabeledContent("Skip / next phase", value: "⌃⌥→")
                LabeledContent("End session", value: "⌃⌥X")
                LabeledContent("Open Pepinillo", value: "⌃⌥P")
            } footer: {
                Text("Starts or pauses the focus timer from anywhere; ⌃⌥T captures a task from any app.")
                    .foregroundStyle(.secondary)
            }

            Section {
                Picker(
                    "Status style",
                    selection: Binding(
                        get: { preferences.menuBarStatusStyle },
                        set: { preferences.setMenuBarStatusStyle($0) }
                    )
                ) {
                    ForEach(MenuBarStatusStyle.allCases, id: \.self) { style in
                        Text(statusStyleLabel(style))
                            .tag(style)
                            .disabled(style.isPro && !store.subscriptionState.isPro)
                    }
                }
            } header: {
                Label(String(localized: "Menu bar"), systemImage: "menubar.rectangle")
            } footer: {
                Text("How the session shows in the menu bar. The minimal styles need Pepinillo+.")
                    .foregroundStyle(.secondary)
            }

            Section {
                Toggle(
                    "Track apps during focus sessions",
                    isOn: Binding(
                        get: { preferences.topActivityEnabled },
                        set: { preferences.setTopActivityEnabled($0) }
                    )
                )
            } header: {
                Label(String(localized: "Usage statistics"), systemImage: "chart.bar")
            } footer: {
                Text("Counts which apps are frontmost while a focus session runs. App names never leave this Mac.")
                    .foregroundStyle(.secondary)
            }

            iCloudSyncSection

            aboutSection
        }
        .formStyle(.grouped)
        .padding()
    }

    /// Mirrors the iPhone iCloud Sync section over the shared SettingsFeature
    /// state (status lives in the app group container).
    @ViewBuilder
    private var iCloudSyncSection: some View {
        Section {
            HStack {
                Label(syncStatusTitle, systemImage: "icloud")
                Spacer()
                if store.settings.isRetryingAppleCloudSync {
                    ProgressView()
                        .controlSize(.small)
                }
            }
            if store.settings.syncStatus == .appleCloudUnavailable {
                Button {
                    store.send(.settings(.retryAppleCloudSyncTapped))
                } label: {
                    Label(String(localized: "Retry iCloud Sync"), systemImage: "arrow.clockwise")
                }
                .disabled(store.settings.isRetryingAppleCloudSync)
            }
        } header: {
            Label(String(localized: "iCloud Sync"), systemImage: "icloud")
        } footer: {
            Text("Back up your focus history through iCloud. Sign in from the Account section to sync tasks across devices.")
                .foregroundStyle(.secondary)
        }
    }

    /// Same mapping as the iPhone settings, reusing its localized labels.
    private var syncStatusTitle: String {
        switch store.settings.syncStatus {
        case .idle, .localOnly:
            return String(localized: "Local only")
        case .activatingAppleCloud:
            return String(localized: "Activating iCloud…")
        case .appleCloudActive:
            return String(localized: "iCloud active")
        case .appleCloudUnavailable:
            return String(localized: "iCloud unavailable")
        case .backendActive:
            return String(localized: "Pepinillo cloud active")
        }
    }

    private var aboutSection: some View {
        Section {
            LabeledContent(String(localized: "Version"), value: appVersion)
            LabeledContent {
                EmptyView()
            } label: {
                Text("Apple-first focus. Sync when you need it.")
            }
        } header: {
            Label(String(localized: "About"), systemImage: "info.circle")
        }
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    // MARK: Focus

    /// Duration, auto-start, and default-mode preferences. Mirrors the iPhone
    /// settings using the same shared `SettingsFeature` actions and the same
    /// localized stepper labels, so en/es/pt come for free.
    private var focus: some View {
        Form {
            Section {
                Picker("Default mode", selection: defaultModeBinding) {
                    ForEach(FocusMode.allCases, id: \.self) { mode in
                        defaultModeLabel(mode).tag(mode)
                    }
                }
            } footer: {
                Text("The mode Pepinillo opens with. Advanced modes need Pepinillo+.")
                    .foregroundStyle(.secondary)
            }

            Section("Pomodoro") {
                Stepper(
                    String(localized: "\(store.settings.pomodoroDurationMinutes) min focus"),
                    value: binding(\.pomodoroDurationMinutes) { .pomodoroDurationChanged($0) },
                    in: 1...120, step: 5
                )
                Stepper(
                    String(localized: "\(store.settings.shortBreakMinutes) min short break"),
                    value: binding(\.shortBreakMinutes) { .shortBreakChanged($0) },
                    in: 1...30, step: 1
                )
                Stepper(
                    String(localized: "\(store.settings.longBreakMinutes) min long break"),
                    value: binding(\.longBreakMinutes) { .longBreakChanged($0) },
                    in: 5...60, step: 5
                )
                Stepper(
                    String(localized: "\(store.settings.pomodorosPerCycle) before long break"),
                    value: binding(\.pomodorosPerCycle) { .pomodorosPerCycleChanged($0) },
                    in: 1...12, step: 1
                )
                Toggle(
                    "Auto-start breaks",
                    isOn: eventBinding(store.settings.autoStartBreaks) { .autoStartBreaksToggled }
                )
                Toggle(
                    "Auto-start work sessions",
                    isOn: eventBinding(store.settings.autoStartWork) { .autoStartWorkToggled }
                )
            }

            Section {
                Stepper(
                    String(localized: "\(store.settings.flowtimeMinMinutes) min minimum session"),
                    value: binding(\.flowtimeMinMinutes) { .flowtimeMinMinutesChanged($0) },
                    in: 1...30, step: 1
                )
            } header: {
                Text("Flowtime")
            } footer: {
                Text("Minimum focus time before a break is suggested.")
                    .foregroundStyle(.secondary)
            }

            Section("Time Block") {
                Stepper(
                    String(localized: "\(store.settings.blockDurationMinutes) min block"),
                    value: binding(\.blockDurationMinutes) { .blockDurationChanged($0) },
                    in: 5...480, step: 15
                )
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private var defaultModeBinding: Binding<FocusMode> {
        Binding(
            get: { store.settings.defaultMode },
            set: { store.send(.settings(.defaultModeChanged($0))) }
        )
    }

    private func defaultModeLabel(_ mode: FocusMode) -> Text {
        guard !store.settings.isProUser, !mode.isFreeTier else {
            return Text(mode.displayName)
        }
        return Text("\(mode.displayName) (Pro)")
    }

    private func binding(
        _ keyPath: KeyPath<SettingsFeature.State, Int>,
        action: @escaping (Int) -> SettingsFeature.Action
    ) -> Binding<Int> {
        Binding(
            get: { store.settings[keyPath: keyPath] },
            set: { store.send(.settings(action($0))) }
        )
    }

    private func eventBinding(
        _ value: Bool,
        action: @escaping () -> SettingsFeature.Action
    ) -> Binding<Bool> {
        Binding(
            get: { value },
            set: { _ in store.send(.settings(action())) }
        )
    }

    // MARK: Notifications

    private var notifications: some View {
        Form {
            Section {
                Toggle(
                    "Sound effects",
                    isOn: eventBinding(store.settings.soundEnabled) { .soundToggled }
                )
                Picker(
                    "Completion sound",
                    selection: Binding(
                        get: { CompletionSound.current },
                        set: { sound in
                            UserDefaults.standard.set(sound.rawValue, forKey: CompletionSound.defaultsKey)
                        }
                    )
                ) {
                    ForEach(CompletionSound.allCases, id: \.self) { sound in
                        Text(sound.displayName).tag(sound)
                    }
                }
                Toggle(
                    "Post-session reflection",
                    isOn: eventBinding(store.settings.showJournalAfterSession) { .showJournalAfterSessionToggled }
                )
            } header: {
                Text("Sessions")
            }

            Section {
                Toggle(
                    "Daily reminder",
                    isOn: eventBinding(store.settings.dailyReminderEnabled) { .dailyReminderToggled }
                )
                if store.settings.dailyReminderEnabled {
                    DatePicker(
                        "Reminder time",
                        selection: reminderTimeBinding,
                        displayedComponents: .hourAndMinute
                    )
                }
            } footer: {
                Text("A nudge to start your first focus of the day.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private var reminderTimeBinding: Binding<Date> {
        Binding(
            get: {
                var comps = Calendar.current.dateComponents([.year, .month, .day], from: Date.now)
                comps.hour = store.settings.dailyReminderHour
                comps.minute = store.settings.dailyReminderMinute
                return Calendar.current.date(from: comps) ?? Date.now
            },
            set: { date in
                let comps = Calendar.current.dateComponents([.hour, .minute], from: date)
                store.send(.settings(.dailyReminderTimeChanged(
                    hour: comps.hour ?? 9,
                    minute: comps.minute ?? 0
                )))
            }
        )
    }

    private var appearance: some View {
        Form {
            Picker(
                "Theme",
                selection: Binding(
                    get: { store.settings.themeName },
                    set: { store.send(.settings(.themeChanged($0))) }
                )
            ) {
                ForEach(AppTheme.all, id: \.name) { theme in
                    Text(theme.displayName).tag(theme.name)
                }
            }

            Picker(
                "Appearance",
                selection: Binding(
                    get: { store.settings.appearanceMode },
                    set: { store.send(.settings(.appearanceModeChanged($0))) }
                )
            ) {
                Text("System").tag("system")
                Text("Light").tag("light")
                Text("Dark").tag("dark")
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}
