// PepinilloWatchApp.swift
// Pepinillo — Deep Work Companion for Apple
//
// Entry point for the watchOS companion app.

import SwiftUI
import ComposableArchitecture

@main
struct PepinilloWatchApp: App {
    var body: some Scene {
        WindowGroup {
            WatchFocusView(
                store: Store(initialState: WatchFocusFeature.State()) {
                    WatchFocusFeature()
                }
            )
        }
    }
}
