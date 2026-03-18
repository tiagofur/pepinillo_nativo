// PepinilloWatchApp.swift
// Pepinillo — Deep Work Companion for Apple
//
// Entry point for the watchOS companion app.
// Uses WatchRootView with vertical-paged TabView for Timer, Tasks, Dashboard.

import SwiftUI
import ComposableArchitecture

@main
struct PepinilloWatchApp: App {
    var body: some Scene {
        WindowGroup {
            WatchRootView(
                store: Store(initialState: WatchAppFeature.State()) {
                    WatchAppFeature()
                }
            )
        }
    }
}
