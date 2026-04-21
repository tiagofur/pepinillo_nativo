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

@main
struct PepinilloApp: App {

    @Environment(\.scenePhase) private var scenePhase

    let modelContainer: ModelContainer?
    let store: StoreOf<AppFeature>?

    @MainActor
    init() {
        // Start Sentry FIRST so any crash during the rest of init is captured.
        // No-op when DSN is empty (Dev builds, open-source contributors, etc.).
        SentryService.start()

        // Install notification delegate and register categories before the app can receive any notifications
        NotificationDelegate.shared.install()
        NotificationClient.registerCategories()

        do {
            // Use the shared App Group container so widgets read the same data.
            // Requires "group.com.pepinillo.app" App Group entitlement on all targets.
            #if targetEnvironment(simulator)
            let container = try makeSharedModelContainer(enableCloudKit: false)
            #else
            let container = try makeSharedModelContainer(enableCloudKit: true)
            #endif
            modelContainer = container

            #if DEBUG
            DemoDataSeeder.seedIfNeeded(container: container)
            #endif

            store = Store(initialState: AppFeature.State()) {
                AppFeature()
            } withDependencies: {
                $0.persistenceClient = PersistenceClient.live(container: container)
                if #available(iOS 16.2, *) {
                    $0.liveActivityClient = LiveActivityManager.makeClient()
                }
                // notificationClient, subscriptionClient, soundscapeClient, signInWithAppleClient
                // use their liveValue automatically via @DependencyKey
            }
        } catch {
            modelContainer = nil
            store = nil
        }
    }

    var body: some Scene {
        WindowGroup {
            if let store = store, let container = modelContainer {
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
                VStack(spacing: 20) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 50))
                        .foregroundStyle(.red)
                    Text("Initialization Failed")
                        .font(.title)
                        .bold()
                    Text("Pepinillo could not load your local data. Please check your available storage space or restart the app.")
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                .padding()
            }
        }
        .defaultSize(width: 1_100, height: 720)
        #if os(macOS) || targetEnvironment(macCatalyst)
        .windowResizability(.contentMinSize)
        #endif
        .commands {
            if let store = store {
                PepinilloCommands(store: store)
            } else {
                EmptyCommands()
            }
        }
    }
}
