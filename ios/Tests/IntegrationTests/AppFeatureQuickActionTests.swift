// AppFeatureQuickActionTests.swift
// Pepinillo — Deep Work Companion for Apple
//
// Home Screen quick actions route to the expected tabs (#733). Mirrors the
// widget deep-link test: pure tab switches, minimal persistence stubs.

import ComposableArchitecture
import Testing
@testable import Pepinillo

@Suite(.serialized, .appGroupDefaultsSerialized)
@MainActor
struct AppFeatureQuickActionTests {

    private func makeStore() -> TestStoreOf<AppFeature> {
        TestStore(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: {
            $0.persistenceClient.resolveAchievements = { derived in derived }
            $0.persistenceClient.fetchPreferences = { UserPreferencesDTO() }
        }
    }

    @Test func quickActionFocusSwitchesTab() async {
        let store = makeStore()
        store.exhaustivity = .off

        await store.send(.quickActionSelected(.focus)) {
            $0.selectedTab = .focus
        }
    }

    @Test func quickActionPlanSwitchesTab() async {
        let store = makeStore()
        store.exhaustivity = .off

        await store.send(.quickActionSelected(.plan)) {
            $0.selectedTab = .plan
        }
    }

    @Test func quickActionOnFreshStateLandsOnFocusTab() async {
        // Cold start with the Start-focus shortcut: State() defaults selectedTab
        // to .focus already — the action must keep it (no crash, no flip).
        let store = makeStore()
        store.exhaustivity = .off

        await store.send(.quickActionSelected(.focus)) {
            $0.selectedTab = .focus
        }
    }
}
