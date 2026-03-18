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
import ComposableArchitecture

@main
struct PepinilloApp: App {

    @Environment(\.scenePhase) private var scenePhase

    let modelContainer: ModelContainer
    let store: StoreOf<AppFeature>

    @MainActor
    init() {
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
                // notificationClient, subscriptionClient, soundscapeClient, signInWithAppleClient
                // use their liveValue automatically via @DependencyKey
            }
        } catch {
            fatalError("Failed to create shared ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            AppView(store: store)
                .modelContainer(modelContainer)
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active {
                        store.send(.appBecameActive)
                    }
                }
        }
        .defaultSize(width: 1_100, height: 720)
        #if os(macOS) || targetEnvironment(macCatalyst)
        .windowResizability(.contentMinSize)
        #endif
        .commands {
            PepinilloCommands(store: store)
        }
    }
}
