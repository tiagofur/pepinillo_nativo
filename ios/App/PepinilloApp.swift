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
import WidgetKit
#if canImport(UIKit)
import UIKit
#endif

private enum AppBootstrapTiming {
    // Keep launch-critical persistence well below the iOS watchdog window.
    // If the shared App Group store is corrupt or blocked by SQLite/SwiftData,
    // the app must fail open into a stable recovery store instead of sitting on
    // the splash/loading screen.
    //
    // Adaptive timeout: if the WAL file is large (> 512 KB) the SQLite open
    // must replay those frames before returning, which takes several seconds on
    // a warm simulator and more on a cold device. We detect this at launch and
    // give the open up to 12 s instead of the standard 3 s cliff.
    // Once the WAL is checkpointed (which we now do before opening), subsequent
    // cold launches will hit the 3 s baseline again.
    static let walCheckpointThresholdBytes: Int = 512 * 1_024    // 512 KB
    static let sharedStoreOpenTimeoutSecondsNormal: TimeInterval = 3
    static let sharedStoreOpenTimeoutSecondsLargeWAL: TimeInterval = 12
    static let recoveryStoreOpenTimeoutSeconds: TimeInterval = 3
    static let inMemoryStoreOpenTimeoutSeconds: TimeInterval = 1.5

    /// Returns the timeout appropriate for the current WAL state of the shared store.
    /// After the first successful open+checkpoint the WAL will be small and this will
    /// return the normal 3 s limit.
    static var sharedStoreOpenTimeoutSeconds: TimeInterval {
        let walBytes = walFileSizeBytes(for: AppGroup.storeURL)
        if walBytes > walCheckpointThresholdBytes {
            return sharedStoreOpenTimeoutSecondsLargeWAL
        }
        return sharedStoreOpenTimeoutSecondsNormal
    }
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

        // Sprint-5 T2: resolve a resume offer BEFORE the launch reconcile below
        // clears the anchors (ghostSnapshotIfNeeded is read-only; the clear
        // happens later). Eligible ghosts surface an offer; the abandon record
        // is deferred to Discard. Everything else keeps the T5 abandon path.
        if let snapshot = AppGroupDefaults.SessionReconcilePolicy.ghostSnapshotIfNeeded(engineIsRunning: false),
           let spec = FocusEngine.resolveGhostResume(
               modeName: AppGroupDefaults.activeModeName,
               timerStart: AppGroupDefaults.activeSessionTimerStart,
               timerEnd: AppGroupDefaults.activeSessionTimerEnd,
               elapsedAnchor: AppGroupDefaults.activeSessionElapsed,
               pomodoroNumber: AppGroupDefaults.activeSessionPomodoroNumber,
               taskID: AppGroupDefaults.activeTaskID,
               now: Date.now
           ) {
            initialState.pendingGhostOffer = (spec: spec, snapshot: snapshot)
        }
        let hadGhostOffer = initialState.pendingGhostOffer != nil

        store = Store(initialState: initialState) {
            AppFeature()
        } withDependencies: {
            let actorBox = router.activeActorBox()
            let persistence = PersistenceClient.live(actorProvider: { actorBox.current })
            $0.persistenceClient = persistence
            $0.syncModeClient.reconcile = { [weak self] capabilities in
                await router.reconcile(capabilities: capabilities)
                await MainActor.run {
                    self?.modelContainer = router.activeContainer
                }
            }
            if #available(iOS 16.2, *) {
                let liveActivityClient = LiveActivityManager.makeClient()
                $0.liveActivityClient = liveActivityClient
                // Clear ghost App Group sessions before Live Activity reconcile (#173).
                // reconcileOnLaunch adopts activities when isSessionActive is true; a killed
                // mid-session process leaves that flag set while FocusEngine is still idle.
                // S6: take a stale external start BEFORE the ghost takeoff below:
                // its optimistic countdown may already be served with no engine
                // to record it. take...() snapshots + clears atomically, so the
                // interval can neither late-adopt nor double-apply.
                let staleBackfill = AppGroupDefaults.SessionReconcilePolicy.takeStaleExternalStartBackfill(engineIsRunning: false)
                // Snapshot a killed mid-session process before clearing (#173, S5).
                let ghostSnapshot = AppGroupDefaults.SessionReconcilePolicy.ghostSnapshotIfNeeded(engineIsRunning: false)
                if AppGroupDefaults.SessionReconcilePolicy.clearGhostSessionIfNeeded(engineIsRunning: false) || staleBackfill != nil {
                    // S6: persist the served-but-unrecorded external interval.
                    if let staleBackfill {
                        let backfill = FocusSessionResult(ghost: staleBackfill)
                        Task { [persistence] in
                            _ = try? await persistence.saveSession(backfill)
                        }
                    }
                    // S5: persist the killed session's focus time as an abandoned
                    // record instead of letting it evaporate. Best-effort on the
                    // launch path; the snapshot was already cleared above.
                    // Sprint-5 T2: skipped while a resume offer is pending — the
                    // abandon is recorded only on Discard (recording now would
                    // double-count on Resume).
                    if !hadGhostOffer, let ghostSnapshot {
                        let ghost = FocusSessionResult(ghost: ghostSnapshot)
                        Task { [persistence] in
                            _ = try? await persistence.saveSession(ghost)
                        }
                    }
                    WidgetCenter.shared.reloadTimelines(ofKind: "FocusHomeScreenWidget")
                    WidgetCenter.shared.reloadTimelines(ofKind: "FocusLockScreenWidget")
                    WidgetCenter.shared.reloadTimelines(ofKind: "TasksHomeScreenWidget")
                }
                Task {
                    await liveActivityClient.reconcileOnLaunch()
                }
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
        // Clear recovery-skip flag so the next cold launch re-attempts the shared store.
        // Without this reset, a single timeout permanently routes all launches to the
        // fallback store, causing split-brain (widget sees shared store, app writes to fallback).
        UserDefaults.standard.removeObject(forKey: AppLaunchDefaults.useRecoveryStoreKey)
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
                            // Checkpoint the WAL on background so the next cold launch does
                            // not need to replay a large WAL file before the store is readable.
                            // Uses a low-priority global queue so it does not delay backgrounding.
                            #if os(iOS) || targetEnvironment(macCatalyst)
                            final class TaskIdBox: @unchecked Sendable {
                                var value: UIBackgroundTaskIdentifier = .invalid
                            }
                            let box = TaskIdBox()
                            let sharedApp = UIApplication.shared
                            box.value = sharedApp.beginBackgroundTask(withName: "WALCheckpoint") {
                                Task { @MainActor [box] in
                                    if box.value != .invalid {
                                        sharedApp.endBackgroundTask(box.value)
                                        box.value = .invalid
                                    }
                                }
                            }
                            DispatchQueue.global(qos: .utility).async {
                                checkpointWAL(at: AppGroup.storeURL)
                                Task { @MainActor [box] in
                                    if box.value != .invalid {
                                        sharedApp.endBackgroundTask(box.value)
                                        box.value = .invalid
                                    }
                                }
                            }
                            #else
                            DispatchQueue.global(qos: .utility).async {
                                checkpointWAL(at: AppGroup.storeURL)
                            }
                            #endif
                        default:
                            break
                        }
                    }
                    .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
                        // Fires at midnight — resets daily Pomodoro counters without interrupting active session
                        store.send(.dayChanged)
                    }
            } else {
                Group {
                    if bootstrap.phase == .failed {
                        VStack(spacing: 16) {
                            Image("LaunchLogo")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 96, height: 96)
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
                        }
                    } else {
                        ZStack {
                            Image("LaunchLogo")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 96, height: 96)
                            
                            VStack {
                                Spacer()
                                ProgressView()
                                Text(bootstrap.statusMessage)
                                    .font(.headline)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.bottom, 80)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemBackground).ignoresSafeArea())
            }
        }
        #if os(macOS) || targetEnvironment(macCatalyst)
        .defaultSize(width: 1_100, height: 720)
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
