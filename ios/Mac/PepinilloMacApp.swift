// PepinilloMacApp.swift
// Pepinillo — native macOS shell

import AppKit
import Carbon
import SwiftData
import SwiftUI
import ComposableArchitecture
import OSLog

private enum MacAppLaunchDefaults {
    static let hasCompletedOnboardingKey = "pepinillo.hasCompletedOnboarding"
}

private enum MacAppBootstrapError: Error {
    case containerTimeout
}

private enum MacAppBootstrapTiming {
    static let containerOpenTimeout: Duration = .seconds(8)
}

private let macStartupLogger = Logger(subsystem: "com.pepinillo.app", category: "mac-startup")

@MainActor
private final class MacAppBootstrap: ObservableObject {
    enum Phase: Equatable {
        case loading
        case ready
        case failed
    }

    @Published var phase: Phase = .loading
    @Published var modelContainer: ModelContainer?
    @Published var store: StoreOf<AppFeature>?
    /// Drives the status item, the Dock chrome, and popover content, none of
    /// which observe the store directly.
    @Published var presence = MacPresencePulse()
    private lazy var statusBar = MacStatusBarController(presence: presence)
    private lazy var quickCapture = MacQuickCaptureController()

    init() {
        Task {
            await bootstrap()
        }
    }

    func retry() {
        Task {
            await bootstrap()
        }
    }

    private func bootstrap() async {
        phase = .loading
        do {
            let container = try await loadContainerSafely()
            apply(container: container)
        } catch {
            macStartupLogger.error("Mac bootstrap failed: \(String(describing: error), privacy: .public)")
            do {
                apply(container: try makeFreshFallbackModelContainer())
            } catch {
                macStartupLogger.error("Mac fallback bootstrap failed: \(String(describing: error), privacy: .public)")
                phase = .failed
            }
        }
    }

    private func loadContainerSafely() async throws -> ModelContainer {
        try await withThrowingTaskGroup(of: ModelContainer.self) { group in
            group.addTask(priority: .userInitiated) {
                try await Task.detached(priority: .userInitiated) {
                    try makeSharedModelContainer()
                }.value
            }
            group.addTask {
                try await Task.sleep(for: MacAppBootstrapTiming.containerOpenTimeout)
                throw MacAppBootstrapError.containerTimeout
            }

            guard let container = try await group.next() else {
                throw MacAppBootstrapError.containerTimeout
            }
            group.cancelAll()
            return container
        }
    }

    private func apply(container: ModelContainer) {
        modelContainer = container

        #if DEBUG
        DemoDataSeeder.seedIfNeeded(container: container)
        #endif

        var initialState = AppFeature.State()
        initialState.hasCompletedOnboarding = UserDefaults.standard.bool(
            forKey: MacAppLaunchDefaults.hasCompletedOnboardingKey
        )

        let defaults = UserDefaults.standard
        let restoredSection = defaults.string(forKey: MacAppStorageKeys.selectedSection)
            ?? defaults.string(forKey: MacAppStorageKeys.defaultSection)
        if let raw = restoredSection,
           let tab = AppFeature.Tab(rawValue: raw),
           tab != .account {
            initialState.selectedTab = tab
        }

        let store = Store(initialState: initialState) {
            AppFeature()
        } withDependencies: {
            $0.persistenceClient = PersistenceClient.live(container: container)
        }
        self.store = store
        phase = .ready

        // AppKit surfaces (Dock menu, Services) need the live store, and the
        // services provider is unretained by NSApplication, so it is kept here.
        MacAppDelegate.current?.store = store
        let servicesProvider = MacServicesProvider(store: store)
        MacAppDelegate.current?.servicesProvider = servicesProvider
        NSApp.servicesProvider = servicesProvider

        // The menu bar can be the only surface at launch, so the launch
        // contract must not depend on the main window appearing.
        store.send(.appLaunched)

        presence.startObserving(store: store)
        statusBar.install(store: store)

        // Global shortcuts share one Carbon handler and dispatch by id.
        MacGlobalHotKey.shared.register(
            id: MacGlobalHotKey.HotKeyID.focusToggle,
            keyCode: kVK_Space,
            modifiers: controlKey | optionKey
        ) {
            FocusToggleCommand.toggle(store: store)
        }
        quickCapture.install(store: store)
        MacGlobalHotKey.shared.register(
            id: MacGlobalHotKey.HotKeyID.quickCapture,
            keyCode: kVK_ANSI_T,
            modifiers: controlKey | optionKey
        ) {
            self.quickCapture.togglePanel()
        }
    }
}

@main
struct PepinilloMacApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @NSApplicationDelegateAdaptor(MacAppDelegate.self) private var appDelegate
    @StateObject private var bootstrap = MacAppBootstrap()
    @StateObject private var preferences = MacPreferences()

    @MainActor
    init() {
        SentryService.start()
        NotificationDelegate.shared.install()
        NotificationClient.registerCategories()
    }

    var body: some Scene {
        Window("Pepinillo", id: "main") {
            if let store = bootstrap.store, let container = bootstrap.modelContainer {
                MacAppView(store: store)
                    .modelContainer(container)
                    .onChange(of: scenePhase) { _, newPhase in
                        switch newPhase {
                        case .active:
                            store.send(.appBecameActive)
                        case .background:
                            store.send(.appWentToBackground)
                        default:
                            break
                        }
                    }
            } else {
                MacBootstrapView(phase: bootstrap.phase) {
                    bootstrap.retry()
                }
            }
        }
        .defaultSize(width: 1_120, height: 760)
        .windowResizability(.contentMinSize)
        .commands {
            if let store = bootstrap.store {
                PepinilloCommands(store: store)
            } else {
                EmptyCommands()
            }
        }

        // The menu bar presence is an AppKit `NSStatusItem`
        // (`MacStatusBarController`): the SwiftUI MenuBarExtra label never
        // re-renders, so the live countdown is drawn into the status button.
        Settings {
            if let store = bootstrap.store {
                MacSettingsView(store: store, preferences: preferences)
            } else {
                ProgressView()
                    .frame(width: 320, height: 200)
            }
        }
    }
}

private struct MacBootstrapView: View {
    let phase: MacAppBootstrap.Phase
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image("LaunchLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 96, height: 96)

            if phase == .failed {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title2)
                    .foregroundStyle(.orange)
                Text("Could not initialize local data")
                    .font(.headline)
                Text("Please retry. If this persists, reinstall the app to reset the local database.")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: 360)
                Button("Retry", action: retry)
                    .buttonStyle(.borderedProminent)
            } else {
                ProgressView()
                Text("Starting Pepinillo...")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.pepinilloSystemBackground.ignoresSafeArea())
    }
}

/// Closing the main window must not stop the timer or quit the menu bar app.
/// The delegate also owns Dock-icon behavior: reopen, badge, and context menu.
@MainActor
final class MacAppDelegate: NSObject, NSApplicationDelegate {
    static private(set) weak var current: MacAppDelegate?

    /// Set by `MacAppBootstrap` once the shared store exists.
    var store: StoreOf<AppFeature>?
    /// NSApplication does not retain `servicesProvider`, so the delegate keeps
    /// it alive.
    var servicesProvider: MacServicesProvider?

    func applicationWillFinishLaunching(_ notification: Notification) {
        Self.current = self
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    /// Clicking the Dock icon with no visible window must bring Pepinillo
    /// back, like any pre-installed app.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            MacStatusBarController.shared?.openMainWindow()
        }
        return true
    }
}
