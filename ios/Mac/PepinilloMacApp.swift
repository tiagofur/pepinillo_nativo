// PepinilloMacApp.swift
// Pepinillo — native macOS shell

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

        store = Store(initialState: initialState) {
            AppFeature()
        } withDependencies: {
            $0.persistenceClient = PersistenceClient.live(container: container)
        }
        phase = .ready
    }
}

@main
struct PepinilloMacApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var bootstrap = MacAppBootstrap()

    @MainActor
    init() {
        SentryService.start()
        NotificationDelegate.shared.install()
        NotificationClient.registerCategories()
    }

    var body: some Scene {
        WindowGroup {
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
        #if os(macOS) || targetEnvironment(macCatalyst)
        .defaultSize(width: 1_120, height: 760)
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

private struct MacBootstrapView: View {
    let phase: MacAppBootstrap.Phase
    let retry: () -> Void

    var body: some View {
        VStack(spacing: SpacingTokens.md) {
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
        .background(Color(.systemBackground).ignoresSafeArea())
    }
}
