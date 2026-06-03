// PepinilloApp.swift
// Pepinillo — Deep Work Companion for Apple
//
// @main entry point. Configures:
// - Shared App Group SwiftData ModelContainer (app + widget + intents read the same store)
// - Root TCA Store with live dependencies injected at startup
// - UNNotificationCenter categories registered at launch
// - Mac Catalyst: window sizing, menu commands

import SwiftUI
import SwiftData
import UserNotifications
import ActivityKit
import ComposableArchitecture
import OSLog

private enum AppBootstrapTiming {
    // Keep launch-critical persistence well below the iOS watchdog window.
    // If the shared App Group store is corrupt or blocked by SQLite/SwiftData,
    // the app must fail open into a stable recovery store instead of sitting on
    // the splash/loading screen.
    static let sharedStoreOpenTimeoutSeconds: TimeInterval = 3
    static let recoveryStoreOpenTimeoutSeconds: TimeInterval = 3
    static let inMemoryStoreOpenTimeoutSeconds: TimeInterval = 1.5
}

private enum AppLaunchDefaults {
    static let hasCompletedOnboardingKey = "pepinillo.hasCompletedOnboarding"
    static let bootstrapStartedAtKey = "pepinillo.bootstrap.startedAt"
    static let bootstrapCompletedAtKey = "pepinillo.bootstrap.completedAt"
    static let useRecoveryStoreKey = "pepinillo.bootstrap.useRecoveryStore"
    static let lastSharedStoreFailureKey = "pepinillo.bootstrap.lastSharedStoreFailure"
}

private let startupLogger = Logger(subsystem: "com.pepinillo.app", category: "startup")

@MainActor
private final class AppBootstrap: ObservableObject {
    enum Phase: Equatable {
        case loading
        case ready
        case failed
    }

    @Published var phase: Phase = .loading
    @Published var statusMessage = String(localized: "Starting Pepinillo...")
    @Published var modelContainer: ModelContainer?
    @Published var persistenceRouter: PersistenceStoreRouter?
    @Published var store: StoreOf<AppFeature>?

    init() {
        // Do not open SwiftData synchronously here. On physical devices the first
        // store open can migrate/validate SQLite and block SwiftUI from rendering,
        // leaving the system launch screen visible long enough to feel hung.
        Task { [weak self] in
            await self?.bootstrap()
        }
    }

    private func bootstrap() async {
        phase = .loading
        markBootstrapStarted()
        startupLogger.info("Starting asynchronous bootstrap phase...")
        do {
            let container = try await loadContainerWithTimeout()
            startupLogger.info("ModelContainer loaded successfully, applying...")
            apply(container: container)
            markBootstrapCompleted()
        } catch {
            startupLogger.error("App bootstrap failed after timeout/error: \(String(describing: error), privacy: .public)")
            phase = .failed
        }
    }

    func retry() {
        startupLogger.info("User requested bootstrap retry")
        Task { [weak self] in
            await self?.bootstrap()
        }
    }

    private func loadContainerWithTimeout() async throws -> ModelContainer {
        if shouldSkipSharedStoreForRecovery {
            startupLogger.warning("Recovery mode is active; skipping shared store and opening stable recovery store.")
            statusMessage = String(localized: "Repairing local data...")
            return try await loadRecoveryContainer()
        }

        do {
            statusMessage = String(localized: "Opening local data...")
            startupLogger.info("Attempting to load shared ModelContainer with launch-safe timeout...")
            return try await loadSharedContainerOnBackgroundQueue()
        } catch {
            startupLogger.warning("Shared container failed or timed out, attempting emergency fallback: \(String(describing: error), privacy: .public)")
            markSharedStoreFailed()
            statusMessage = String(localized: "Repairing local data...")
            return try await loadRecoveryContainer()
        }
    }

    private func loadRecoveryContainer() async throws -> ModelContainer {
        do {
            return try await loadStableFallbackContainerOnBackgroundQueue()
        } catch {
            startupLogger.error("Stable fallback container failed/timed out, attempting fresh fallback store: \(String(describing: error), privacy: .public)")
            do {
                return try await loadFreshFallbackContainerOnBackgroundQueue()
            } catch {
                startupLogger.error("Fresh fallback container failed/timed out, attempting in-memory emergency store: \(String(describing: error), privacy: .public)")
                statusMessage = String(localized: "Opening recovery mode...")
                do {
                    return try await loadInMemoryContainerOnBackgroundQueue()
                } catch {
                    startupLogger.fault("Critical failure: in-memory emergency container failed/timed out: \(String(describing: error), privacy: .public)")
                    throw error
                }
            }
        }
    }

    private func loadSharedContainerOnBackgroundQueue() async throws -> ModelContainer {
        try await openModelContainerOffMainThread(
            label: "shared-app-group",
            timeout: AppBootstrapTiming.sharedStoreOpenTimeoutSeconds
        ) {
            try makeSharedModelContainer()
        }
    }

    private func loadStableFallbackContainerOnBackgroundQueue() async throws -> ModelContainer {
        try await openModelContainerOffMainThread(
            label: "stable-fallback",
            timeout: AppBootstrapTiming.recoveryStoreOpenTimeoutSeconds
        ) {
            try makeFallbackModelContainer()
        }
    }

    private func loadFreshFallbackContainerOnBackgroundQueue() async throws -> ModelContainer {
        try await openModelContainerOffMainThread(
            label: "fresh-fallback",
            timeout: AppBootstrapTiming.recoveryStoreOpenTimeoutSeconds
        ) {
            try Self.makeEmergencyFallbackContainer()
        }
    }

    private func loadInMemoryContainerOnBackgroundQueue() async throws -> ModelContainer {
        try await openModelContainerOffMainThread(
            label: "in-memory-emergency",
            timeout: AppBootstrapTiming.inMemoryStoreOpenTimeoutSeconds
        ) {
            try Self.makeInMemoryEmergencyContainer()
        }
    }

    private func apply(container: ModelContainer) {
        let router = PersistenceStoreRouter(localContainer: container)
        persistenceRouter = router
        modelContainer = router.activeContainer

        #if DEBUG
        DemoDataSeeder.seedIfNeeded(container: container)
        #endif

        var initialState = AppFeature.State()
        initialState.hasCompletedOnboarding = UserDefaults.standard.bool(
            forKey: AppLaunchDefaults.hasCompletedOnboardingKey
        )

        store = Store(initialState: initialState) {
            AppFeature()
        } withDependencies: {
            $0.persistenceClient = PersistenceClient.live(serviceProvider: { router.activeService() })
            $0.syncModeClient.reconcile = { [weak self] capabilities in
                await router.reconcile(capabilities: capabilities)
                await MainActor.run {
                    self?.modelContainer = router.activeContainer
                }
            }
            if #available(iOS 16.2, *) {
                $0.liveActivityClient = LiveActivityManager.makeClient()
            }
        }
        phase = .ready
    }

    nonisolated private static func makeEmergencyFallbackContainer() throws -> ModelContainer {
        try makeFreshFallbackModelContainer()
    }

    nonisolated private static func makeInMemoryEmergencyContainer() throws -> ModelContainer {
        try makeInMemoryModelContainer()
    }

    private var shouldSkipSharedStoreForRecovery: Bool {
        let defaults = UserDefaults.standard
        if defaults.bool(forKey: AppLaunchDefaults.useRecoveryStoreKey) {
            return true
        }

        let startedAt = defaults.double(forKey: AppLaunchDefaults.bootstrapStartedAtKey)
        let completedAt = defaults.double(forKey: AppLaunchDefaults.bootstrapCompletedAtKey)
        guard startedAt > completedAt else { return false }

        let unfinishedAge = Date().timeIntervalSince1970 - startedAt
        return unfinishedAge > AppBootstrapTiming.sharedStoreOpenTimeoutSeconds
    }

    private func markBootstrapStarted() {
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: AppLaunchDefaults.bootstrapStartedAtKey)
    }

    private func markBootstrapCompleted() {
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: AppLaunchDefaults.bootstrapCompletedAtKey)
    }

    private func markSharedStoreFailed() {
        let defaults = UserDefaults.standard
        defaults.set(true, forKey: AppLaunchDefaults.useRecoveryStoreKey)
        defaults.set(Date().timeIntervalSince1970, forKey: AppLaunchDefaults.lastSharedStoreFailureKey)
    }
}

@main
struct PepinilloApp: App {

    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var bootstrap = AppBootstrap()

    @MainActor
    init() {
        // Start Sentry FIRST so any crash during the rest of init is captured.
        // No-op when DSN is empty (Dev builds, open-source contributors, etc.).
        SentryService.start()

        // Install notification delegate and register categories before the app can receive any notifications
        NotificationDelegate.shared.install()
        NotificationClient.registerCategories()

        // Startup heavy work (SwiftData store open + migration) is performed asynchronously
        // by AppBootstrap so first SwiftUI frame renders immediately on physical devices.
    }

    var body: some Scene {
        WindowGroup {
            if let store = bootstrap.store, let container = bootstrap.modelContainer {
                AppView(store: store)
                    .modelContainer(container)
                    .onChange(of: scenePhase) { _, newPhase in
                        switch newPhase {
                        case .active:
                            // Detect day change while app was backgrounded overnight
                            let today = Calendar.current.startOfDay(for: Date.now)
                            let key = "pep_lastActiveDayStart"
                            let lastTimestamp = UserDefaults.standard.double(forKey: key)
                            UserDefaults.standard.set(today.timeIntervalSince1970, forKey: key)
                            if lastTimestamp > 0 && Date(timeIntervalSince1970: lastTimestamp) < today {
                                store.send(.dayChanged)
                            }
                            store.send(.appBecameActive)
                        case .background:
                            store.send(.appWentToBackground)
                        default:
                            break
                        }
                    }
                    .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
                        // Fires at midnight — resets daily Pomodoro counters without interrupting active session
                        store.send(.dayChanged)
                    }
            } else {
                VStack(spacing: 16) {
                    Image("LaunchLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 96, height: 96)
                    if bootstrap.phase == .failed {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.title2)
                            .foregroundStyle(.orange)
                        Text("Could not initialize local data")
                            .font(.headline)
                        Text("Please retry. If this persists, reinstall the app to reset the local database.")
                            .font(.subheadline)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 28)
                        Button("Retry") {
                            bootstrap.retry()
                        }
                        .buttonStyle(.borderedProminent)
                    } else {
                        ProgressView()
                        Text(bootstrap.statusMessage)
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color("LaunchBackground").ignoresSafeArea())
            }
        }
        .defaultSize(width: 1_100, height: 720)
        #if os(macOS) || targetEnvironment(macCatalyst)
        .windowResizability(.contentMinSize)
        #endif
        .commands {
            if let store = bootstrap.store {
                PepinilloCommands(store: store)
            } else {
                EmptyCommands()
            }
        }
    }
}
