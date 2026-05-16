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

private enum AppBootstrapError: Error {
    case containerTimeout
}

private enum AppBootstrapTiming {
    static let containerOpenTimeout: Duration = .seconds(8)
}

private enum AppLaunchDefaults {
    static let hasCompletedOnboardingKey = "pepinillo.hasCompletedOnboarding"
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
    @Published var modelContainer: ModelContainer?
    @Published var persistenceRouter: PersistenceStoreRouter?
    @Published var store: StoreOf<AppFeature>?

    init() {
        // Perform purely asynchronous bootstrap to ensure immediate SwiftUI frame rendering.
        // Synchronous ModelContainer initialization in init() blocks the main thread
        // and keeps the system splash screen visible, leading to watchdog kills on physical devices.
        Task {
            await bootstrap()
        }
    }

    private func bootstrap() async {
        phase = .loading
        startupLogger.info("Starting bootstrap phase...")
        do {
            let container = try await loadContainerWithTimeout()
            startupLogger.info("ModelContainer loaded successfully, applying...")
            apply(container: container)
        } catch {
            startupLogger.error("App bootstrap failed after timeout/error: \(String(describing: error), privacy: .public)")
            phase = .failed
        }
    }

    func retry() {
        startupLogger.info("User requested bootstrap retry")
        Task {
            await bootstrap()
        }
    }

    private func loadContainerWithTimeout() async throws -> ModelContainer {
        do {
            startupLogger.info("Attempting to load shared ModelContainer with 8s timeout...")
            return try await withTimeout(seconds: 8) {
                try await self.loadSharedContainerOnBackgroundQueue()
            }
        } catch {
            startupLogger.warning("Shared container failed or timed out, attempting emergency fallback: \(String(describing: error), privacy: .public)")
            
            // Second attempt: fresh fallback store with its own timeout
            do {
                return try await withTimeout(seconds: 8) {
                    try await self.loadFallbackContainerOnBackgroundQueue()
                }
            } catch {
                startupLogger.fault("Critical failure: Fallback container also failed/timed out: \(String(describing: error), privacy: .public)")
                throw error
            }
        }
    }

    private func loadSharedContainerOnBackgroundQueue() async throws -> ModelContainer {
        // Use GCD for the potentially blocking synchronous SwiftData init.
        // This avoids starving the Swift Concurrency cooperative thread pool
        // if the SQLite open/migration hangs.
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let container = try makeSharedModelContainer()
                    continuation.resume(returning: container)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func loadFallbackContainerOnBackgroundQueue() async throws -> ModelContainer {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let container = try Self.makeEmergencyFallbackContainer()
                    continuation.resume(returning: container)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func withTimeout<T: Sendable>(seconds: Double, operation: @escaping @Sendable () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw AppBootstrapError.containerTimeout
            }
            
            guard let result = try await group.next() else {
                throw AppBootstrapError.containerTimeout
            }
            group.cancelAll()
            return result
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

    private static func makeEmergencyFallbackContainer() throws -> ModelContainer {
        try makeFreshFallbackModelContainer()
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
                        Text("Starting Pepinillo...")
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
