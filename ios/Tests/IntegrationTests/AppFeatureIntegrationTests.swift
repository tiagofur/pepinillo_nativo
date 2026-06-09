// AppFeatureIntegrationTests.swift
// Pepinillo — Deep Work Companion for Apple
//
// Integration tests for AppFeature: tab navigation, task→focus cross-feature
// coordination, and onboarding state persistence.

import Testing
import Foundation
import ComposableArchitecture
@testable import Pepinillo

@Suite(.serialized, .appGroupDefaultsSerialized)
@MainActor
struct AppFeatureIntegrationTests {

    @Test func tabSelectionUpdatesState() async {
        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: {
            $0.persistenceClient.fetchPreferences = { UserPreferencesDTO() }
            $0.persistenceClient.savePreferences = { _ in }
            $0.persistenceClient.fetchSessions = { _, _ in [] }
        }
        store.exhaustivity = .off

        await store.send(.tabSelected(.plan)) {
            $0.selectedTab = .plan
        }

        await store.send(.tabSelected(.dashboard)) {
            $0.selectedTab = .dashboard
        }
    }

    @Test func widgetDeepLinksSelectExpectedTabs() async throws {
        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: {
            $0.persistenceClient.fetchPreferences = { UserPreferencesDTO() }
        }

        await store.send(.appURLReceived(try #require(URL(string: "pepinillo://plan")))) {
            $0.selectedTab = .plan
        }

        await store.send(.appURLReceived(try #require(URL(string: "pepinillo://focus")))) {
            $0.selectedTab = .focus
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
            $0.focusClient.start = { _, _, _, _, _, _ in }
            $0.focusClient.events = { AsyncStream { $0.finish() } }
            $0.soundscapeClient.play = { _, _ in }
            $0.watchConnectivityClient.sendSessionState = { _ in }
        }

        store.exhaustivity = .off

        await store.send(.tasks(.startFocusOnTask(taskID))) {
            $0.selectedTab = .focus
        }

        await store.receive(.focus(.linkTask(taskID, "Code the feature", "🧠"))) {
            $0.focus.linkedTaskID = taskID
            $0.focus.linkedTaskTitle = "Code the feature"
            $0.focus.linkedTaskEmoji = "🧠"
        }
    }

    @Test func sessionPersistedRefreshesPlanPomodoroProgress() async {
        var initialState = AppFeature.State()
        let taskID = UUID()
        initialState.tasks.tasks = [
            TaskListFeature.TaskItemState(
                id: taskID,
                title: "Code the feature",
                isCompleted: false,
                priority: .high,
                energyLevel: .deep,
                estimatedPomodoros: 5,
                completedPomodoros: 0,
                subtaskProgress: .init(completed: 0, total: 0),
                isRecurringTemplate: false,
                scheduledForToday: true,
                sortOrder: 0,
                createdAt: .now
            )
        ]

        let refreshedTask = TaskItemDTO(
            id: taskID,
            title: "Code the feature",
            isCompleted: false,
            priority: .high,
            energyLevel: .deep,
            estimatedPomodoros: 5,
            completedPomodoros: 1,
            scheduledForToday: true
        )

        let store = TestStore(initialState: initialState) {
            AppFeature()
        } withDependencies: {
            $0.persistenceClient.fetchPreferences = { UserPreferencesDTO() }
            $0.persistenceClient.fetchTasks = { [refreshedTask] }
            $0.watchConnectivityClient.sendTasks = { _ in }
        }

        store.exhaustivity = .off

        await store.send(.focus(.delegate(.sessionPersisted)))

        await store.receive(.tasks(.tasksLoaded([.from(refreshedTask)]))) {
            $0.tasks.tasks[id: taskID]?.completedPomodoros = 1
            $0.focus.availableTasks[id: taskID]?.completedPomodoros = 1
        }
    }

    @Test func completedPomodoroWorkPhaseIncrementsLinkedTaskProgress() async {
        var initialState = AppFeature.State()
        let taskID = UUID()
        initialState.focus.linkedTaskID = taskID
        initialState.focus.linkedTaskTitle = "Code the feature"
        initialState.focus.activeMode = .pomodoro
        initialState.tasks.tasks = [
            TaskListFeature.TaskItemState(
                id: taskID,
                title: "Code the feature",
                isCompleted: false,
                priority: .high,
                energyLevel: .deep,
                estimatedPomodoros: 5,
                completedPomodoros: 0,
                subtaskProgress: .init(completed: 0, total: 0),
                isRecurringTemplate: false,
                scheduledForToday: true,
                sortOrder: 0,
                createdAt: .now
            )
        ]

        let incrementedTaskIDs = LockIsolated<[UUID]>([])
        let refreshedTask = TaskItemDTO(
            id: taskID,
            title: "Code the feature",
            isCompleted: false,
            priority: .high,
            energyLevel: .deep,
            estimatedPomodoros: 5,
            completedPomodoros: 1,
            scheduledForToday: true
        )

        let store = TestStore(initialState: initialState) {
            AppFeature()
        } withDependencies: {
            $0.persistenceClient.fetchPreferences = { UserPreferencesDTO() }
            $0.persistenceClient.incrementTaskPomodoros = { id in incrementedTaskIDs.withValue { $0.append(id) } }
            $0.persistenceClient.fetchTasks = { [refreshedTask] }
            $0.notificationClient.scheduleWorkPhaseEnd = { _, _, _ in }
            $0.watchConnectivityClient.sendTasks = { _ in }
        }

        store.exhaustivity = .off

        await store.send(.focus(.phaseCompleted(.work(number: 1, total: 5))))

        await store.receive(.focus(.delegate(.taskProgressChanged)))
        await store.receive(.tasks(.tasksLoaded([.from(refreshedTask)]))) {
            $0.tasks.tasks[id: taskID]?.completedPomodoros = 1
            $0.focus.availableTasks[id: taskID]?.completedPomodoros = 1
        }

        #expect(incrementedTaskIDs.value == [taskID])
    }

    @Test func appLaunchSetsOnboardingFlagIfPreviouslyCompleted() async {
        let savedDefaults = AppGroupDefaultsSnapshot.capture()
        defer { savedDefaults.restore() }
        AppGroupDefaults.clearExternalCommands()
        AppGroupDefaults.clearActiveSession()

        var prefs = UserPreferencesDTO()
        prefs.hasCompletedOnboarding = true
        let completedPrefs = prefs

        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: {
            $0.persistenceClient.fetchPreferences = { completedPrefs }
            $0.persistenceClient.savePreferences = { _ in }
            $0.persistenceClient.fetchCachedUser = { nil }
            $0.persistenceClient.fetchSessions = { _, _ in [] }
            $0.persistenceClient.generateRecurringTasks = { }
            $0.persistenceClient.fetchTasks = { [] }
            $0.subscriptionClient.checkEntitlement = { .free }
            $0.subscriptionClient.listenForTransactionUpdates = { AsyncStream { $0.finish() } }
            $0.notificationClient.requestAuthorization = { false }
            $0.notificationClient.observeActions = { .finished }
            $0.watchConnectivityClient.isSupported = { false }
            $0.watchConnectivityClient.sendTasks = { _ in }
            $0.signInWithAppleClient.checkCredentialState = { _ in false }
            $0.keychainClient.hasTokens = { false }
            $0.spotlightClient.indexTasks = { _ in }
            $0.syncModeClient.reconcile = { _ in }
            $0.syncClient.syncAll = { }
            $0.webSocketClient.connect = { }
            $0.webSocketClient.disconnect = { }
            $0.focusClient.start = { _, _, _, _, _, _ in }
            $0.focusClient.events = { AsyncStream { $0.finish() } }
            $0.focusClient.currentState = { nil }
            $0.liveActivityClient.isAvailable = { false }
            $0.soundscapeClient.play = { _, _ in }
        }

        store.exhaustivity = .off

        await store.send(.appLaunched)

        await store.receive(.onboardingCompleted) {
            $0.hasCompletedOnboarding = true
        }
    }

    @Test func appLaunchDoesNotSetOnboardingFlagForNewUser() async {
        let savedDefaults = AppGroupDefaultsSnapshot.capture()
        defer { savedDefaults.restore() }
        AppGroupDefaults.clearExternalCommands()
        AppGroupDefaults.clearActiveSession()

        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: {
            $0.persistenceClient.fetchPreferences = { UserPreferencesDTO() }
            $0.persistenceClient.savePreferences = { _ in }
            $0.persistenceClient.fetchCachedUser = { nil }
            $0.persistenceClient.fetchSessions = { _, _ in [] }
            $0.persistenceClient.generateRecurringTasks = { }
            $0.persistenceClient.fetchTasks = { [] }
            $0.subscriptionClient.checkEntitlement = { .free }
            $0.subscriptionClient.listenForTransactionUpdates = { AsyncStream { $0.finish() } }
            $0.notificationClient.requestAuthorization = { false }
            $0.notificationClient.observeActions = { .finished }
            $0.watchConnectivityClient.isSupported = { false }
            $0.watchConnectivityClient.sendTasks = { _ in }
            $0.signInWithAppleClient.checkCredentialState = { _ in false }
            $0.keychainClient.hasTokens = { false }
            $0.spotlightClient.indexTasks = { _ in }
            $0.syncModeClient.reconcile = { _ in }
            $0.syncClient.syncAll = { }
            $0.webSocketClient.connect = { }
            $0.webSocketClient.disconnect = { }
            $0.focusClient.start = { _, _, _, _, _, _ in }
            $0.focusClient.events = { AsyncStream { $0.finish() } }
            $0.focusClient.currentState = { nil }
            $0.liveActivityClient.isAvailable = { false }
            $0.soundscapeClient.play = { _, _ in }
        }

        store.exhaustivity = .off

        await store.send(.appLaunched)
        #expect(store.state.hasCompletedOnboarding == false)
    }

    @Test func appleSignInSeedsProfileFromIdentityWhenBackendUserIsUnavailable() async {
        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: {
            $0.persistenceClient.fetchPreferences = { UserPreferencesDTO() }
            $0.persistenceClient.savePreferences = { _ in }
            $0.persistenceClient.fetchCachedUser = { nil }
            $0.persistenceClient.saveCachedUser = { _ in }
            $0.subscriptionClient.logIn = { _ in }
            $0.keychainClient.hasTokens = { false }
        }

        store.exhaustivity = .off

        await store.send(
            .signInWithAppleSucceeded(
                AppleUserInfo(
                    userID: "apple-user-123",
                    displayName: "Tiago",
                    email: "tiago@example.com"
                )
            )
        ) {
            $0.appleUserID = "apple-user-123"
            $0.displayName = "Tiago"
            $0.userEmail = "tiago@example.com"
        }

        await store.send(.showProfile) {
            $0.profile = ProfileFeature.State(
                user: CachedUserDTO(
                    id: "apple-user-123",
                    email: "tiago@example.com",
                    name: "Tiago",
                    subscriptionTier: "free",
                    emailVerified: true,
                    appleId: "apple-user-123"
                )
            )
        }
    }

    @Test func showProfileMergesRestoredAppleIdentityWithCachedProfileFields() async {
        var initialState = AppFeature.State()
        initialState.appleUserID = "apple-user-123"
        initialState.displayName = "Tiago"
        initialState.userEmail = "tiago@example.com"

        let cachedUser = CachedUserDTO(
            id: "apple-user-123",
            email: "",
            name: "",
            imageUrl: nil,
            birthDate: "1990-05-20T00:00:00Z",
            subscriptionTier: "free",
            emailVerified: false,
            appleId: "apple-user-123",
            createdAt: "",
            updatedAt: ""
        )

        let store = TestStore(initialState: initialState) {
            AppFeature()
        }

        await store.send(.cachedUserLoaded(cachedUser)) {
            $0.cachedUser = cachedUser
        }

        #expect(store.state.displayName == "Tiago")
        #expect(store.state.userEmail == "tiago@example.com")

        await store.send(.showProfile) {
            $0.profile = ProfileFeature.State(
                user: CachedUserDTO(
                    id: "apple-user-123",
                    email: "tiago@example.com",
                    name: "Tiago",
                    imageUrl: nil,
                    birthDate: "1990-05-20T00:00:00Z",
                    subscriptionTier: "free",
                    emailVerified: false,
                    appleId: "apple-user-123",
                    createdAt: "",
                    updatedAt: ""
                )
            )
        }
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
            $0.persistenceClient.fetchSessions = { _, _ in [] }
            $0.watchConnectivityClient.sendSessionState = { _ in }
            $0.focusClient.start = { _, _, _, _, _, _ in }
            $0.focusClient.events = { AsyncStream { $0.finish() } }
            $0.focusClient.currentState = { nil }
            $0.liveActivityClient.isAvailable = { false }
            $0.soundscapeClient.play = { _, _ in }
        }

        store.exhaustivity = .off

        await store.send(.watchCommandReceived(.startSession(mode: "pomodoro")))
        await store.receive(.focus(.modeSelected(.pomodoro)))
        await store.receive(.focus(.startTapped()))
    }

    @Test func watchCommandStartSessionWithUnknownModeUsesCurrentMode() async {
        var initialState = AppFeature.State()
        initialState.focus.selectedMode = .flowtime

        let store = TestStore(initialState: initialState) {
            AppFeature()
        } withDependencies: {
            $0.persistenceClient.fetchPreferences = { UserPreferencesDTO() }
            $0.watchConnectivityClient.sendSessionState = { _ in }
            $0.focusClient.start = { _, _, _, _, _, _ in }
            $0.focusClient.events = { AsyncStream { $0.finish() } }
            $0.focusClient.currentState = { nil }
            $0.liveActivityClient.isAvailable = { false }
            $0.soundscapeClient.play = { _, _ in }
        }

        store.exhaustivity = .off

        await store.send(.watchCommandReceived(.startSession(mode: "unknown_mode")))
        await store.receive(.focus(.modeSelected(.flowtime)))
        await store.receive(.focus(.startTapped()))
    }

    // MARK: - Widget Command Reconciliation

    @Test func appBecameActiveConsumesWidgetStartedSessionWithAnchors() async throws {
        let savedDefaults = AppGroupDefaultsSnapshot.capture()
        defer { savedDefaults.restore() }

        AppGroupDefaults.clearExternalCommands()
        AppGroupDefaults.clearActiveSession()
        AppGroupDefaults.pomodoroDuration = 25 * 60
        let issuedAt = Date(timeIntervalSince1970: 1_800_000_000)
        AppGroupDefaults.startWidgetSession(modeID: "pomodoro", issuedAt: issuedAt)
        let timerStart = try #require(AppGroupDefaults.activeSessionTimerStart)
        let timerEnd = try #require(AppGroupDefaults.activeSessionTimerEnd)

        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: {
            $0.persistenceClient.fetchPreferences = { UserPreferencesDTO() }
            $0.persistenceClient.fetchSessions = { _, _ in [] }
            $0.watchConnectivityClient.sendSessionState = { _ in }
            $0.focusClient.start = { _, _, _, _, _, _ in }
            $0.focusClient.events = { AsyncStream { $0.finish() } }
            $0.focusClient.currentState = { nil }
            $0.liveActivityClient.isAvailable = { false }
            $0.soundscapeClient.play = { _, _ in }
        }

        store.exhaustivity = .off

        await store.send(.appBecameActive)
        await store.receive(.consumeExternalCommands)
        await store.receive(.focus(.modeSelected(.pomodoro)))
        await store.receive(.focus(.startTapped(timerStart: timerStart, timerEnd: timerEnd)))

        #expect(AppGroupDefaults.externalStartRequested == false)
        #expect(AppGroupDefaults.externalCommandID == nil)
    }

    @Test func widgetStartedTaskSessionWaitsForTasksBeforeStartingFocus() async throws {
        let savedDefaults = AppGroupDefaultsSnapshot.capture()
        defer { savedDefaults.restore() }

        AppGroupDefaults.clearExternalCommands()
        AppGroupDefaults.clearActiveSession()
        AppGroupDefaults.pomodoroDuration = 25 * 60
        let taskID = UUID()
        let issuedAt = Date(timeIntervalSince1970: 1_800_000_100)
        AppGroupDefaults.startWidgetSession(
            modeID: "pomodoro",
            taskID: taskID.uuidString,
            taskTitle: "Review widget polish",
            issuedAt: issuedAt
        )
        let timerStart = try #require(AppGroupDefaults.activeSessionTimerStart)
        let timerEnd = try #require(AppGroupDefaults.activeSessionTimerEnd)

        let task = TaskListFeature.TaskItemState(
            id: taskID,
            title: "Review widget polish",
            isCompleted: false,
            priority: .medium,
            energyLevel: .deep,
            estimatedPomodoros: 2,
            completedPomodoros: 0,
            subtaskProgress: .init(completed: 0, total: 0),
            isRecurringTemplate: false,
            scheduledForToday: true,
            sortOrder: 0,
            createdAt: .now
        )
        let taskDTO = TaskItemDTO(
            id: taskID,
            title: task.title,
            isCompleted: task.isCompleted,
            priority: task.priority,
            energyLevel: task.energyLevel,
            estimatedPomodoros: task.estimatedPomodoros,
            completedPomodoros: task.completedPomodoros,
            sortOrder: task.sortOrder,
            scheduledForToday: task.scheduledForToday,
            createdAt: task.createdAt
        )

        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: {
            $0.persistenceClient.fetchPreferences = { UserPreferencesDTO() }
            $0.persistenceClient.fetchSessions = { _, _ in [] }
            $0.persistenceClient.fetchTasks = { [taskDTO] }
            $0.persistenceClient.generateRecurringTasks = { }
            $0.watchConnectivityClient.sendSessionState = { _ in }
            $0.watchConnectivityClient.sendTasks = { _ in }
            $0.spotlightClient.indexTasks = { _ in }
            $0.focusClient.start = { _, _, _, _, _, _ in }
            $0.focusClient.events = { AsyncStream { $0.finish() } }
            $0.focusClient.currentState = { nil }
            $0.liveActivityClient.isAvailable = { false }
            $0.soundscapeClient.play = { _, _ in }
        }

        store.exhaustivity = .off

        await store.send(.consumeExternalCommands) {
            $0.pendingExternalStartModeID = "pomodoro"
            $0.pendingExternalStartTaskID = taskID.uuidString
            $0.pendingExternalStartTimerStart = timerStart
            $0.pendingExternalStartTimerEnd = timerEnd
        }
        await store.receive(.tasks(.onAppear)) {
            $0.tasks.isLoading = true
        }

        await store.receive(.tasks(.tasksLoaded([task]))) {
            $0.tasks.tasks = [task]
            $0.tasks.isLoading = false
            $0.focus.availableTasks = [task]
            $0.pendingExternalStartModeID = nil
            $0.pendingExternalStartTaskID = nil
            $0.pendingExternalStartTimerStart = nil
            $0.pendingExternalStartTimerEnd = nil
        }
        await store.receive(.focus(.linkTask(taskID, "Review widget polish", "🧠")))
        await store.receive(.focus(.modeSelected(.pomodoro)))
        await store.receive(.focus(.startTapped(timerStart: timerStart, timerEnd: timerEnd)))
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

    // MARK: - UserCapabilities propagation to App Group

    @Test func subscriptionStateLoadedWritesCapabilitiesToAppGroup() async {
        let saved = AppGroupDefaults.userCapabilities
        defer { AppGroupDefaults.userCapabilities = saved }
        AppGroupDefaults.userCapabilities = nil

        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: {
            $0.persistenceClient.fetchPreferences = { UserPreferencesDTO() }
            $0.syncModeClient.reconcile = { _ in }
            $0.keychainClient.hasTokens = { false }
            $0.syncClient.syncAll = { }
            $0.webSocketClient.connect = { }
            $0.webSocketClient.disconnect = { }
        }
        store.exhaustivity = .off

        await store.send(.subscriptionStateLoaded(.everywherePlus)) {
            $0.subscriptionState = .everywherePlus
            $0.focus.isProUser = true
            $0.settings.isProUser = true
            $0.analytics.isProUser = true
            $0.tasks.isProUser = true
        }

        // After subscriptionStateLoaded, userCapabilities should be written to App Group
        let caps = AppGroupDefaults.userCapabilities
        #expect(caps?.backendSync == true)
        #expect(caps?.hasAnyPremium == true)
    }

    @Test func subscriptionUpdatedWritesCapabilitiesToAppGroup() async {
        let saved = AppGroupDefaults.userCapabilities
        defer { AppGroupDefaults.userCapabilities = saved }
        AppGroupDefaults.userCapabilities = nil

        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: {
            $0.persistenceClient.fetchPreferences = { UserPreferencesDTO() }
            $0.syncModeClient.reconcile = { _ in }
            $0.keychainClient.hasTokens = { false }
            $0.syncClient.syncAll = { }
            $0.webSocketClient.connect = { }
            $0.webSocketClient.disconnect = { }
        }
        store.exhaustivity = .off

        await store.send(.subscriptionUpdated(.pepinilloPlus)) {
            $0.subscriptionState = .pepinilloPlus
            $0.focus.isProUser = true
            $0.settings.isProUser = true
            $0.analytics.isProUser = true
            $0.tasks.isProUser = true
        }

        let caps = AppGroupDefaults.userCapabilities
        #expect(caps?.backendSync == false)
        #expect(caps?.localPremium == true)
        #expect(caps?.hasAnyPremium == true)
    }

    @Test func subscriptionUpdatedFreeWritesFreeCapabilities() async {
        let saved = AppGroupDefaults.userCapabilities
        defer { AppGroupDefaults.userCapabilities = saved }
        AppGroupDefaults.userCapabilities = .everywherePlus

        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: {
            $0.persistenceClient.fetchPreferences = { UserPreferencesDTO() }
            $0.syncModeClient.reconcile = { _ in }
            $0.keychainClient.hasTokens = { false }
            $0.syncClient.syncAll = { }
            $0.webSocketClient.connect = { }
            $0.webSocketClient.disconnect = { }
        }
        store.exhaustivity = .off

        await store.send(.subscriptionUpdated(.free)) {
            $0.subscriptionState = .free
            $0.focus.isProUser = false
            $0.settings.isProUser = false
            $0.analytics.isProUser = false
            $0.tasks.isProUser = false
        }

        let caps = AppGroupDefaults.userCapabilities
        #expect(caps?.backendSync == false)
        #expect(caps?.hasAnyPremium == false)
    }

    @Test func subscriptionStateLoadedUpdatesProStatus() async {
        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: {
            $0.persistenceClient.fetchPreferences = { UserPreferencesDTO() }
            $0.syncModeClient.reconcile = { _ in }
            $0.keychainClient.hasTokens = { false }
            $0.syncClient.syncAll = { }
            $0.webSocketClient.connect = { }
            $0.webSocketClient.disconnect = { }
        }
        store.exhaustivity = .off

        await store.send(.subscriptionStateLoaded(.pro)) {
            $0.subscriptionState = .pro
            $0.focus.isProUser = true
            $0.settings.isProUser = true
            $0.analytics.isProUser = true
            $0.tasks.isProUser = true
        }
    }

    @Test func subscriptionUpdatedHidesPaywallWhenPro() async {
        var initialState = AppFeature.State()
        initialState.focus.showPaywall = true

        let store = TestStore(initialState: initialState) {
            AppFeature()
        } withDependencies: {
            $0.persistenceClient.fetchPreferences = { UserPreferencesDTO() }
            $0.syncModeClient.reconcile = { _ in }
            $0.keychainClient.hasTokens = { false }
            $0.syncClient.syncAll = { }
            $0.webSocketClient.connect = { }
            $0.webSocketClient.disconnect = { }
        }
        store.exhaustivity = .off

        await store.send(.subscriptionUpdated(.pro)) {
            $0.subscriptionState = .pro
            $0.focus.isProUser = true
            $0.settings.isProUser = true
            $0.analytics.isProUser = true
            $0.tasks.isProUser = true
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
        await store.receive(.settings(.upgradeTapped)) {
            $0.focus.showPaywall = true
        }
        // Settings emits upgradeTapped; AppFeature translates to focus.showPaywall = true
        #expect(store.state.focus.showPaywall == true)
        #expect(store.state.settings.themeName == "default")
    }
}
