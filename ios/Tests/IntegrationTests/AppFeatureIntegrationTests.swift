// AppFeatureIntegrationTests.swift
// Pepinillo — Deep Work Companion for Apple
//
// Integration tests for AppFeature: tab navigation, task→focus cross-feature
// coordination, and onboarding state persistence.

import Testing
import Foundation
import ComposableArchitecture
@testable import Pepinillo

@MainActor
struct AppFeatureIntegrationTests {

    @Test func tabSelectionUpdatesState() async {
        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: {
            $0.persistenceClient.fetchPreferences = { UserPreferencesDTO() }
            $0.persistenceClient.savePreferences = { _ in }
        }

        await store.send(.tabSelected(.tasks)) {
            $0.selectedTab = .tasks
        }

        await store.send(.tabSelected(.analytics)) {
            $0.selectedTab = .analytics
        }
    }

    @Test func onboardingCompletedSetsFlag() async {
        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: {
            $0.persistenceClient.fetchPreferences = { UserPreferencesDTO() }
            $0.persistenceClient.savePreferences = { _ in }
        }

        store.exhaustivity = .off

        await store.send(.onboardingCompleted) {
            $0.hasCompletedOnboarding = true
        }
    }

    @Test func startFocusOnTaskSwitchesTabAndLinksTask() async {
        var initialState = AppFeature.State()
        let taskID = UUID()
        initialState.tasks.tasks = [
            TaskListFeature.TaskItemState(
                id: taskID,
                title: "Code the feature",
                isCompleted: false,
                priority: .high,
                energyLevel: .deep,
                estimatedPomodoros: 3,
                completedPomodoros: 0,
                subtaskProgress: .init(completed: 0, total: 0),
                isRecurringTemplate: false,
                scheduledForToday: false,
                sortOrder: 0,
                createdAt: .now
            )
        ]

        let store = TestStore(initialState: initialState) {
            AppFeature()
        } withDependencies: {
            $0.persistenceClient.fetchPreferences = { UserPreferencesDTO() }
            $0.persistenceClient.fetchSessions = { _, _ in [] }
        }

        store.exhaustivity = .off

        await store.send(.tasks(.startFocusOnTask(taskID))) {
            $0.selectedTab = .focus
        }

        await store.receive(.focus(.linkTask(taskID, "Code the feature"))) {
            $0.focus.linkedTaskID = taskID
            $0.focus.linkedTaskTitle = "Code the feature"
        }
    }

    @Test func appLaunchSetsOnboardingFlagIfPreviouslyCompleted() async {
        var prefs = UserPreferencesDTO()
        prefs.hasCompletedOnboarding = true
        let completedPrefs = prefs

        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: {
            $0.persistenceClient.fetchPreferences = { completedPrefs }
            $0.persistenceClient.savePreferences = { _ in }
            $0.subscriptionClient.checkEntitlement = { .free }
            $0.subscriptionClient.listenForTransactionUpdates = { AsyncStream { $0.finish() } }
            $0.notificationClient.requestAuthorization = { false }
            $0.notificationClient.observeActions = { .finished }
            $0.watchConnectivityClient.isSupported = { false }
            $0.signInWithAppleClient.checkCredentialState = { _ in false }
        }

        store.exhaustivity = .off

        await store.send(.appLaunched)

        await store.receive(.onboardingCompleted) {
            $0.hasCompletedOnboarding = true
        }
    }

    @Test func appLaunchDoesNotSetOnboardingFlagForNewUser() async {
        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: {
            $0.persistenceClient.fetchPreferences = { UserPreferencesDTO() }
            $0.persistenceClient.savePreferences = { _ in }
            $0.subscriptionClient.checkEntitlement = { .free }
            $0.subscriptionClient.listenForTransactionUpdates = { AsyncStream { $0.finish() } }
            $0.notificationClient.requestAuthorization = { false }
            $0.notificationClient.observeActions = { .finished }
            $0.watchConnectivityClient.isSupported = { false }
            $0.signInWithAppleClient.checkCredentialState = { _ in false }
        }

        store.exhaustivity = .off

        await store.send(.appLaunched)
        #expect(store.state.hasCompletedOnboarding == false)
    }

    // MARK: - Watch Command Bridge (Watch → iOS)

    @Test func watchCommandPauseSessionDispatchesPauseTapped() async {
        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: {
            $0.persistenceClient.fetchPreferences = { UserPreferencesDTO() }
            $0.watchConnectivityClient.sendSessionState = { _ in }
        }

        store.exhaustivity = .off

        await store.send(.watchCommandReceived(.pauseSession))
        await store.receive(.focus(.pauseTapped))
    }

    @Test func watchCommandResumeSessionDispatchesResumeTapped() async {
        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: {
            $0.persistenceClient.fetchPreferences = { UserPreferencesDTO() }
            $0.watchConnectivityClient.sendSessionState = { _ in }
        }

        store.exhaustivity = .off

        await store.send(.watchCommandReceived(.resumeSession))
        await store.receive(.focus(.resumeTapped))
    }

    @Test func watchCommandStopSessionDispatchesStopTapped() async {
        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: {
            $0.persistenceClient.fetchPreferences = { UserPreferencesDTO() }
            $0.persistenceClient.fetchDailyStats = { _ in nil }
            $0.watchConnectivityClient.sendSessionState = { _ in }
            $0.watchConnectivityClient.sendStats = { _, _, _ in }
            $0.focusClient.stop = { _ in }
            $0.liveActivityClient.end = { _ in }
            $0.soundscapeClient.fadeOut = { }
        }

        store.exhaustivity = .off

        await store.send(.watchCommandReceived(.stopSession))
        await store.receive(.focus(.stopTapped))
    }

    @Test func watchCommandStartSessionDispatchesModeSelectedAndStartTapped() async {
        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: {
            $0.persistenceClient.fetchPreferences = { UserPreferencesDTO() }
            $0.watchConnectivityClient.sendSessionState = { _ in }
            $0.focusClient.start = { _, _, _, _ in }
            $0.focusClient.events = { AsyncStream { $0.finish() } }
            $0.focusClient.currentState = { nil }
            $0.liveActivityClient.isAvailable = { false }
            $0.soundscapeClient.play = { _, _ in }
        }

        store.exhaustivity = .off

        await store.send(.watchCommandReceived(.startSession(mode: "pomodoro")))
        await store.receive(.focus(.modeSelected(.pomodoro)))
        await store.receive(.focus(.startTapped))
    }

    @Test func watchCommandStartSessionWithUnknownModeUsesCurrentMode() async {
        var initialState = AppFeature.State()
        initialState.focus.selectedMode = .flowtime

        let store = TestStore(initialState: initialState) {
            AppFeature()
        } withDependencies: {
            $0.persistenceClient.fetchPreferences = { UserPreferencesDTO() }
            $0.watchConnectivityClient.sendSessionState = { _ in }
            $0.focusClient.start = { _, _, _, _ in }
            $0.focusClient.events = { AsyncStream { $0.finish() } }
            $0.focusClient.currentState = { nil }
            $0.liveActivityClient.isAvailable = { false }
            $0.soundscapeClient.play = { _, _ in }
        }

        store.exhaustivity = .off

        await store.send(.watchCommandReceived(.startSession(mode: "unknown_mode")))
        await store.receive(.focus(.modeSelected(.flowtime)))
        await store.receive(.focus(.startTapped))
    }

    // MARK: - Celebration Milestones

    @Test func celebrationTriggeredStoresMilestone() async {
        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: {
            $0.persistenceClient.fetchPreferences = { UserPreferencesDTO() }
        }

        await store.send(.celebrationTriggered(.streakDay(7))) {
            $0.pendingCelebration = .streakDay(7)
        }
    }

    @Test func celebrationDismissedClearsMilestone() async {
        var initialState = AppFeature.State()
        initialState.pendingCelebration = .streakDay(7)

        let store = TestStore(initialState: initialState) {
            AppFeature()
        } withDependencies: {
            $0.persistenceClient.fetchPreferences = { UserPreferencesDTO() }
        }

        await store.send(.celebrationDismissed) {
            $0.pendingCelebration = nil
        }
    }

    @Test func celebrationMilestoneCheckMatchesExpectedStreakValues() {
        let expectedMilestones = [3, 7, 14, 30, 60, 100]
        for day in expectedMilestones {
            #expect(CelebrationMilestone.checkStreak(day) != nil, "Expected milestone at \(day) days")
        }
        for day in [1, 2, 4, 5, 6, 8, 15, 25, 50] {
            #expect(CelebrationMilestone.checkStreak(day) == nil, "Expected no milestone at \(day) days")
        }
    }

    // MARK: - Subscription State

    @Test func subscriptionStateLoadedUpdatesProStatus() async {
        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: {
            $0.persistenceClient.fetchPreferences = { UserPreferencesDTO() }
        }
        store.exhaustivity = .off

        await store.send(.subscriptionStateLoaded(.pro)) {
            $0.subscriptionState = .pro
            $0.focus.isProUser = true
            $0.settings.isProUser = true
            $0.analytics.isProUser = true
        }
    }

    @Test func subscriptionUpdatedHidesPaywallWhenPro() async {
        var initialState = AppFeature.State()
        initialState.focus.showPaywall = true

        let store = TestStore(initialState: initialState) {
            AppFeature()
        } withDependencies: {
            $0.persistenceClient.fetchPreferences = { UserPreferencesDTO() }
        }
        store.exhaustivity = .off

        await store.send(.subscriptionUpdated(.pro)) {
            $0.subscriptionState = .pro
            $0.focus.isProUser = true
            $0.settings.isProUser = true
            $0.analytics.isProUser = true
            $0.focus.showPaywall = false
        }
    }

    @Test func analyticsPaywallRequestedShowsPaywall() async {
        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: {
            $0.persistenceClient.fetchPreferences = { UserPreferencesDTO() }
        }
        store.exhaustivity = .off

        await store.send(.analytics(.paywallRequested)) {
            $0.focus.showPaywall = true
        }
    }

    @Test func settingsThemeChangeForFreeUserShowsPaywall() async {
        var initialState = AppFeature.State()
        initialState.settings.isProUser = false
        initialState.settings.themeName = "default"

        let store = TestStore(initialState: initialState) {
            AppFeature()
        } withDependencies: {
            $0.persistenceClient.fetchPreferences = { UserPreferencesDTO() }
            $0.persistenceClient.savePreferences = { _ in }
        }
        store.exhaustivity = .off

        await store.send(.settings(.themeChanged("ocean")))
        // Settings emits upgradeTapped; AppFeature translates to focus.showPaywall = true
        #expect(store.state.focus.showPaywall == true)
        #expect(store.state.settings.themeName == "default")
    }
}
