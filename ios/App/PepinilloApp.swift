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
    @Published var store: StoreOf<AppFeature>?

    init() {
        installFallbackStore()
        Task {
            await bootstrap()
        }
    }

    private func bootstrap() async {
        do {
            let container = try await loadContainerSafely()
            apply(container: container)
        } catch {
            startupLogger.error("App bootstrap failed: \(String(describing: error), privacy: .public)")
        }
    }

    func retry() {
        Task {
            await bootstrap()
        }
    }

    private func loadContainerSafely() async throws -> ModelContainer {
        do {
            return try await Self.makeSharedContainerWithTimeout(seconds: 8)
        } catch {
            startupLogger.error("Persistent store failed during launch, using fallback store: \(String(describing: error), privacy: .public)")
            return try Self.makeEmergencyFallbackContainer()
        }
    }

    private static func makeSharedContainerWithTimeout(seconds: TimeInterval) async throws -> ModelContainer {
        try await withThrowingTaskGroup(of: ModelContainer.self) { group in
            group.addTask {
                try await Task.detached(priority: .userInitiated) {
                    try makeSharedModelContainer()
                }.value
            }
            group.addTask {
                try await Task.sleep(for: .seconds(seconds))
                throw AppBootstrapError.containerTimeout
            }

            guard let first = try await group.next() else {
                throw AppBootstrapError.containerTimeout
            }
            group.cancelAll()
            return first
        }
    }

    private func installFallbackStore() {
        do {
            let container = try Self.makeEmergencyFallbackContainer()
            apply(container: container)
        } catch {
            startupLogger.error("Fallback store setup failed: \(String(describing: error), privacy: .public)")
            phase = .failed
        }
    }

    private func apply(container: ModelContainer) {
        modelContainer = container

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
            $0.persistenceClient = PersistenceClient.live(container: container)
            if #available(iOS 16.2, *) {
                $0.liveActivityClient = LiveActivityManager.makeClient()
            }
        }
        phase = .ready
    }

    private static func makeEmergencyFallbackContainer() throws -> ModelContainer {
        try makeFallbackModelContainer()
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
