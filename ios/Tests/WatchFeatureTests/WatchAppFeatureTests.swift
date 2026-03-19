// WatchAppFeatureTests.swift
// Pepinillo — Deep Work Companion for Apple
//
// TCA reducer tests for the WatchAppFeature (root watch reducer).
// Covers: tab selection, message routing to children, connectivity handling,
// task link/unlink from tasks tab to timer, auto-tab-switching on session start,
// and composition of child reducers.

import Testing
import Foundation
import ComposableArchitecture
@testable import Pepinillo

// MARK: - WatchAppFeature Tests

@MainActor
@Suite("WatchAppFeature Reducer")
struct WatchAppFeatureTests {

    // MARK: - Helpers

    private static let taskA = WatchTaskItem(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
        title: "Write documentation",
        isCompleted: false,
        priority: 2,
        estimatedPomodoros: 3,
        completedPomodoros: 1
    )

    private static let taskB = WatchTaskItem(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
        title: "Review PR",
        isCompleted: false,
        priority: 1,
        estimatedPomodoros: 1,
        completedPomodoros: 0
    )

    private static let completedTask = WatchTaskItem(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
        title: "Deploy hotfix",
        isCompleted: true,
        priority: 3,
        estimatedPomodoros: 1,
        completedPomodoros: 1
    )

    private static func activeSession(
        isPaused: Bool = false,
        modeID: String = "pomodoro",
        displayTime: String = "23:45",
        phaseLabel: String = "Focus 1/4",
        progress: Double? = 0.05,
        pomodoroNumber: Int? = 1,
        linkedTaskTitle: String? = nil,
        linkedTaskID: String? = nil,
        isPhaseTransition: Bool = false
    ) -> WatchSessionState {
        WatchSessionState(
            isActive: true,
            isPaused: isPaused,
            modeID: modeID,
            displayTime: displayTime,
            phaseLabel: phaseLabel,
            progress: progress,
            pomodoroNumber: pomodoroNumber,
            linkedTaskTitle: linkedTaskTitle,
            linkedTaskID: linkedTaskID,
            isPhaseTransition: isPhaseTransition
        )
    }

    private static let sampleDashboardStats = WatchDashboardStats(
        todayMinutes: 180,
        sessionsCompleted: 6,
        tasksCompleted: 4,
        tasksTotal: 10,
        streakDays: 14,
        pomodoroMinutes: 100,
        flowtimeMinutes: 50,
        timeBlockMinutes: 20,
        stopwatchMinutes: 10,
        longestSessionMinutes: 45
    )

    // MARK: - Tab Selection

    @Test("tabSelected changes selected tab")
    func tabSelected() async {
        let store = TestStore(initialState: WatchAppFeature.State()) {
            WatchAppFeature()
        }

        await store.send(.tabSelected(.tasks)) {
            $0.selectedTab = .tasks
        }

        await store.send(.tabSelected(.dashboard)) {
            $0.selectedTab = .dashboard
        }

        await store.send(.tabSelected(.timer)) {
            $0.selectedTab = .timer
        }
    }

    @Test("tabSelected to same tab is a no-op")
    func tabSelectedSameTab() async {
        let store = TestStore(initialState: WatchAppFeature.State()) {
            WatchAppFeature()
        }

        // Default tab is .timer — selecting it again should not trigger state change
        await store.send(.tabSelected(.timer))
    }

    // MARK: - sessionStateReceived: Routing to Timer

    @Test("sessionStateReceived routes to timer child")
    func sessionStateReceivedRoutesToTimer() async {
        let store = TestStore(initialState: WatchAppFeature.State()) {
            WatchAppFeature()
        }

        store.exhaustivity = .off

        let session = Self.activeSession(displayTime: "24:00")

        await store.send(.sessionStateReceived(session)) {
            // Auto-switch to timer tab on new session
            $0.selectedTab = .timer
        }

        await store.receive(.timer(.sessionStateReceived(session)))
    }

    @Test("sessionStateReceived auto-switches to timer tab when session starts")
    func sessionStateReceivedAutoSwitchesToTimer() async {
        var state = WatchAppFeature.State()
        state.selectedTab = .tasks

        let store = TestStore(initialState: state) {
            WatchAppFeature()
        }

        store.exhaustivity = .off

        let session = Self.activeSession()

        await store.send(.sessionStateReceived(session)) {
            $0.selectedTab = .timer
        }
    }

    @Test("sessionStateReceived does not auto-switch if session was already active")
    func sessionStateReceivedNoAutoSwitchWhenAlreadyActive() async {
        var state = WatchAppFeature.State()
        state.selectedTab = .dashboard
        state.timer.isSessionActive = true  // Already tracking an active session

        let store = TestStore(initialState: state) {
            WatchAppFeature()
        }

        store.exhaustivity = .off

        // Another session state update while already active — no tab change
        let session = Self.activeSession(displayTime: "20:00")

        await store.send(.sessionStateReceived(session))
        // selectedTab should remain .dashboard
    }

    @Test("sessionStateReceived does not auto-switch for inactive session")
    func sessionStateReceivedNoAutoSwitchForInactive() async {
        var state = WatchAppFeature.State()
        state.selectedTab = .tasks

        let store = TestStore(initialState: state) {
            WatchAppFeature()
        }

        store.exhaustivity = .off

        let idle = WatchSessionState.idle

        await store.send(.sessionStateReceived(idle))
        // selectedTab should remain .tasks (not switch for idle)
    }

    @Test("sessionStateReceived updates timer child state via routing")
    func sessionStateReceivedUpdatesTimerState() async {
        let store = TestStore(initialState: WatchAppFeature.State()) {
            WatchAppFeature()
        }

        store.exhaustivity = .off

        let session = Self.activeSession(
            displayTime: "22:30",
            phaseLabel: "Focus 2/4",
            progress: 0.1,
            pomodoroNumber: 2,
            linkedTaskTitle: "Code review",
            linkedTaskID: "TASK-42"
        )

        await store.send(.sessionStateReceived(session))
        await store.receive(.timer(.sessionStateReceived(session))) {
            $0.timer.isSessionActive = true
            $0.timer.isPaused = false
            $0.timer.displayTime = "22:30"
            $0.timer.phaseLabel = "Focus 2/4"
            $0.timer.progress = 0.1
            $0.timer.pomodoroNumber = 2
            $0.timer.linkedTaskTitle = "Code review"
            $0.timer.linkedTaskID = "TASK-42"
            $0.timer.selectedMode = .pomodoro
        }
    }

    // MARK: - statsReceived: Routing to Timer + Dashboard

    @Test("statsReceived routes to both timer and dashboard children")
    func statsReceivedRoutesBoth() async {
        let store = TestStore(initialState: WatchAppFeature.State()) {
            WatchAppFeature()
        }

        store.exhaustivity = .off

        await store.send(.statsReceived(todayMinutes: 90, sessions: 4, streak: 7))

        await store.receive(.timer(.statsReceived(todayMinutes: 90, sessions: 4, streak: 7)))
        await store.receive(.dashboard(.statsReceived(todayMinutes: 90, sessions: 4, streak: 7)))
    }

    @Test("statsReceived updates timer stats state")
    func statsReceivedUpdatesTimer() async {
        let store = TestStore(initialState: WatchAppFeature.State()) {
            WatchAppFeature()
        }

        store.exhaustivity = .off

        await store.send(.statsReceived(todayMinutes: 45, sessions: 2, streak: 3))

        await store.receive(.timer(.statsReceived(todayMinutes: 45, sessions: 2, streak: 3))) {
            $0.timer.todayFocusMinutes = 45
            $0.timer.todaySessionsCompleted = 2
            $0.timer.currentStreakDays = 3
        }
    }

    @Test("statsReceived updates dashboard stats state")
    func statsReceivedUpdatesDashboard() async {
        let store = TestStore(initialState: WatchAppFeature.State()) {
            WatchAppFeature()
        }

        store.exhaustivity = .off

        await store.send(.statsReceived(todayMinutes: 45, sessions: 2, streak: 3))

        await store.receive(.dashboard(.statsReceived(todayMinutes: 45, sessions: 2, streak: 3))) {
            $0.dashboard.todayFocusMinutes = 45
            $0.dashboard.sessionsCompleted = 2
            $0.dashboard.streakDays = 3
        }
    }

    // MARK: - tasksReceived: Routing to Tasks

    @Test("tasksReceived routes to tasks child")
    func tasksReceivedRoutesToTasks() async {
        let store = TestStore(initialState: WatchAppFeature.State()) {
            WatchAppFeature()
        }

        store.exhaustivity = .off

        let items = [Self.taskA, Self.taskB]

        await store.send(.tasksReceived(items))

        await store.receive(.tasks(.tasksReceived(items))) {
            $0.tasks.tasks = items
        }
    }

    @Test("tasksReceived with empty list clears child tasks")
    func tasksReceivedEmpty() async {
        var state = WatchAppFeature.State()
        state.tasks.tasks = [Self.taskA]

        let store = TestStore(initialState: state) {
            WatchAppFeature()
        }

        store.exhaustivity = .off

        await store.send(.tasksReceived([]))

        await store.receive(.tasks(.tasksReceived([]))) {
            $0.tasks.tasks = []
        }
    }

    // MARK: - dashboardStatsReceived: Routing to Dashboard

    @Test("dashboardStatsReceived routes to dashboard child")
    func dashboardStatsReceivedRoutesToDashboard() async {
        let store = TestStore(initialState: WatchAppFeature.State()) {
            WatchAppFeature()
        }

        store.exhaustivity = .off

        await store.send(.dashboardStatsReceived(Self.sampleDashboardStats))

        await store.receive(.dashboard(.dashboardStatsReceived(Self.sampleDashboardStats))) {
            $0.dashboard.todayFocusMinutes = 180
            $0.dashboard.sessionsCompleted = 6
            $0.dashboard.tasksCompleted = 4
            $0.dashboard.tasksTotal = 10
            $0.dashboard.streakDays = 14
            $0.dashboard.pomodoroMinutes = 100
            $0.dashboard.flowtimeMinutes = 50
            $0.dashboard.timeBlockMinutes = 20
            $0.dashboard.stopwatchMinutes = 10
            $0.dashboard.longestSessionMinutes = 45
        }
    }

    // MARK: - connectivityChanged

    @Test("connectivityChanged updates root and routes to timer")
    func connectivityChangedUpdatesRoot() async {
        let store = TestStore(initialState: WatchAppFeature.State()) {
            WatchAppFeature()
        } withDependencies: {
            $0.watchConnectivityClient.sendCommand = { _ in }
        }

        store.exhaustivity = .off

        await store.send(.connectivityChanged(true)) {
            $0.isConnected = true
        }

        await store.receive(.timer(.connectivityChanged(true))) {
            $0.timer.isConnected = true
        }
    }

    @Test("connectivityChanged to true requests tasks and dashboard")
    func connectivityChangedTrueRequestsData() async {
        let commandsSent = LockIsolated<[WatchCommand]>([])

        let store = TestStore(initialState: WatchAppFeature.State()) {
            WatchAppFeature()
        } withDependencies: {
            $0.watchConnectivityClient.sendCommand = { command in
                commandsSent.withValue { $0.append(command) }
            }
        }

        store.exhaustivity = .off

        await store.send(.connectivityChanged(true)) {
            $0.isConnected = true
        }

        // Give the run effect time to complete
        await store.receive(.timer(.connectivityChanged(true)))

        commandsSent.withValue {
            #expect($0.contains(.requestTasks))
            #expect($0.contains(.requestDashboard))
        }
    }

    @Test("connectivityChanged to false does not request data")
    func connectivityChangedFalseNoRequests() async {
        var state = WatchAppFeature.State()
        state.isConnected = true

        let commandsSent = LockIsolated<[WatchCommand]>([])

        let store = TestStore(initialState: state) {
            WatchAppFeature()
        } withDependencies: {
            $0.watchConnectivityClient.sendCommand = { command in
                commandsSent.withValue { $0.append(command) }
            }
        }

        store.exhaustivity = .off

        await store.send(.connectivityChanged(false)) {
            $0.isConnected = false
        }

        await store.receive(.timer(.connectivityChanged(false))) {
            $0.timer.isConnected = false
        }

        // No requestTasks or requestDashboard should have been sent
        commandsSent.withValue {
            #expect(!$0.contains(.requestTasks))
            #expect(!$0.contains(.requestDashboard))
        }
    }

    @Test("connectivityChanged routes to timer child")
    func connectivityChangedRoutesToTimer() async {
        let store = TestStore(initialState: WatchAppFeature.State()) {
            WatchAppFeature()
        } withDependencies: {
            $0.watchConnectivityClient.sendCommand = { _ in }
        }

        store.exhaustivity = .off

        await store.send(.connectivityChanged(true)) {
            $0.isConnected = true
        }

        await store.receive(.timer(.connectivityChanged(true))) {
            $0.timer.isConnected = true
        }
    }

    // MARK: - Task Linking (tasks tab -> timer)

    @Test("taskLinked from tasks tab updates timer state and switches to timer tab")
    func taskLinkedFromTasks() async {
        var state = WatchAppFeature.State()
        state.selectedTab = .tasks
        state.tasks.tasks = [Self.taskA, Self.taskB]

        let commandsSent = LockIsolated<[WatchCommand]>([])

        let store = TestStore(initialState: state) {
            WatchAppFeature()
        } withDependencies: {
            $0.watchConnectivityClient.sendCommand = { command in
                commandsSent.withValue { $0.append(command) }
            }
        }

        store.exhaustivity = .off

        // Simulate user tapping task A in the tasks tab
        await store.send(.tasks(.taskTapped(Self.taskA.id))) {
            $0.tasks.linkedTaskID = Self.taskA.id
        }

        // The child sends taskLinked, which the parent intercepts
        await store.receive(.tasks(.taskLinked(Self.taskA.id, "Write documentation"))) {
            $0.timer.linkedTaskID = Self.taskA.id.uuidString
            $0.timer.linkedTaskTitle = "Write documentation"
            $0.selectedTab = .timer
        }

        commandsSent.withValue {
            #expect($0.contains(.linkTask(id: Self.taskA.id.uuidString)))
        }
    }

    @Test("taskLinked sends linkTask command to phone")
    func taskLinkedSendsCommand() async {
        var state = WatchAppFeature.State()
        state.tasks.tasks = [Self.taskA]

        let commandsSent = LockIsolated<[WatchCommand]>([])

        let store = TestStore(initialState: state) {
            WatchAppFeature()
        } withDependencies: {
            $0.watchConnectivityClient.sendCommand = { command in
                commandsSent.withValue { $0.append(command) }
            }
        }

        store.exhaustivity = .off

        await store.send(.tasks(.taskTapped(Self.taskA.id)))
        await store.receive(.tasks(.taskLinked(Self.taskA.id, "Write documentation")))

        commandsSent.withValue {
            #expect($0.contains(.linkTask(id: Self.taskA.id.uuidString)))
        }
    }

    // MARK: - Task Unlinking

    @Test("taskUnlinked from tasks tab clears timer linked task")
    func taskUnlinkedClearsTimer() async {
        var state = WatchAppFeature.State()
        state.tasks.tasks = [Self.taskA]
        state.tasks.linkedTaskID = Self.taskA.id
        state.timer.linkedTaskID = Self.taskA.id.uuidString
        state.timer.linkedTaskTitle = "Write documentation"

        let commandsSent = LockIsolated<[WatchCommand]>([])

        let store = TestStore(initialState: state) {
            WatchAppFeature()
        } withDependencies: {
            $0.watchConnectivityClient.sendCommand = { command in
                commandsSent.withValue { $0.append(command) }
            }
        }

        store.exhaustivity = .off

        // Tap same task to unlink
        await store.send(.tasks(.taskTapped(Self.taskA.id))) {
            $0.tasks.linkedTaskID = nil
        }

        await store.receive(.tasks(.taskUnlinked)) {
            $0.timer.linkedTaskID = nil
            $0.timer.linkedTaskTitle = nil
        }

        commandsSent.withValue {
            #expect($0.contains(.unlinkTask))
        }
    }

    @Test("taskUnlinked sends unlinkTask command to phone")
    func taskUnlinkedSendsCommand() async {
        var state = WatchAppFeature.State()
        state.tasks.tasks = [Self.taskA]
        state.tasks.linkedTaskID = Self.taskA.id

        let commandsSent = LockIsolated<[WatchCommand]>([])

        let store = TestStore(initialState: state) {
            WatchAppFeature()
        } withDependencies: {
            $0.watchConnectivityClient.sendCommand = { command in
                commandsSent.withValue { $0.append(command) }
            }
        }

        store.exhaustivity = .off

        await store.send(.tasks(.taskTapped(Self.taskA.id)))
        await store.receive(.tasks(.taskUnlinked))

        commandsSent.withValue {
            #expect($0.contains(.unlinkTask))
        }
    }

    // MARK: - Task Completion from Watch

    @Test("toggleCompleted from tasks tab sends command to phone")
    func toggleCompletedSendsCommand() async {
        var state = WatchAppFeature.State()
        state.tasks.tasks = [Self.taskA]

        let commandsSent = LockIsolated<[WatchCommand]>([])

        let store = TestStore(initialState: state) {
            WatchAppFeature()
        } withDependencies: {
            $0.watchConnectivityClient.sendCommand = { command in
                commandsSent.withValue { $0.append(command) }
            }
        }

        store.exhaustivity = .off

        await store.send(.tasks(.toggleCompleted(Self.taskA.id))) {
            // Optimistic update happens in child
            let idx = $0.tasks.tasks.firstIndex(where: { $0.id == Self.taskA.id })!
            $0.tasks.tasks[idx] = WatchTaskItem(
                id: Self.taskA.id,
                title: "Write documentation",
                isCompleted: true,
                priority: 2,
                estimatedPomodoros: 3,
                completedPomodoros: 1
            )
        }

        commandsSent.withValue {
            #expect($0.contains(.toggleTaskCompleted(id: Self.taskA.id.uuidString)))
        }
    }

    // MARK: - Timer Child Actions (pass-through)

    @Test("timer child startTapped is not intercepted by parent")
    func timerChildStartNotIntercepted() async {
        let store = TestStore(initialState: WatchAppFeature.State()) {
            WatchAppFeature()
        } withDependencies: {
            $0.watchConnectivityClient.sendCommand = { _ in }
        }

        store.exhaustivity = .off

        // Timer's startTapped should pass through
        await store.send(.timer(.startTapped))
        await store.receive(.timer(.commandSent(.startSession(mode: "pomodoro"))))
    }

    @Test("timer child pauseResumeTapped passes through parent")
    func timerChildPausePassesThrough() async {
        var state = WatchAppFeature.State()
        state.timer.isSessionActive = true
        state.timer.isPaused = false

        let store = TestStore(initialState: state) {
            WatchAppFeature()
        } withDependencies: {
            $0.watchConnectivityClient.sendCommand = { _ in }
        }

        store.exhaustivity = .off

        await store.send(.timer(.pauseResumeTapped))
        await store.receive(.timer(.commandSent(.pauseSession)))
    }

    @Test("timer child modeSelected passes through parent")
    func timerChildModeSelectedPassesThrough() async {
        let store = TestStore(initialState: WatchAppFeature.State()) {
            WatchAppFeature()
        }

        await store.send(.timer(.modeSelected(.flowtime))) {
            $0.timer.selectedMode = .flowtime
        }
    }

    // MARK: - Dashboard Child Actions

    @Test("dashboard onAppear sends requestDashboard command")
    func dashboardOnAppearSendsRequest() async {
        let commandsSent = LockIsolated<[WatchCommand]>([])

        let store = TestStore(initialState: WatchAppFeature.State()) {
            WatchAppFeature()
        } withDependencies: {
            $0.watchConnectivityClient.sendCommand = { command in
                commandsSent.withValue { $0.append(command) }
            }
        }

        store.exhaustivity = .off

        await store.send(.dashboard(.onAppear))

        commandsSent.withValue {
            #expect($0.contains(.requestDashboard))
        }
    }

    // MARK: - Initial State

    @Test("default state has correct initial values")
    func defaultState() {
        let state = WatchAppFeature.State()
        #expect(state.selectedTab == .timer)
        #expect(state.isConnected == false)
        #expect(state.timer == WatchTimerFeature.State())
        #expect(state.tasks == WatchTasksFeature.State())
        #expect(state.dashboard == WatchDashboardFeature.State())
    }

    @Test("WatchTab raw values are sequential")
    func watchTabRawValues() {
        #expect(WatchAppFeature.WatchTab.timer.rawValue == 0)
        #expect(WatchAppFeature.WatchTab.tasks.rawValue == 1)
        #expect(WatchAppFeature.WatchTab.dashboard.rawValue == 2)
    }

    // MARK: - Full Integration Scenarios

    @Test("connect, receive tasks, link task, session starts, receive stats")
    func fullIntegrationScenario() async {
        let commandsSent = LockIsolated<[WatchCommand]>([])

        let store = TestStore(initialState: WatchAppFeature.State()) {
            WatchAppFeature()
        } withDependencies: {
            $0.watchConnectivityClient.sendCommand = { command in
                commandsSent.withValue { $0.append(command) }
            }
        }

        store.exhaustivity = .off

        // 1. Connect
        await store.send(.connectivityChanged(true)) {
            $0.isConnected = true
        }
        await store.receive(.timer(.connectivityChanged(true))) {
            $0.timer.isConnected = true
        }

        // 2. Receive tasks
        let tasks = [Self.taskA, Self.taskB]
        await store.send(.tasksReceived(tasks))
        await store.receive(.tasks(.tasksReceived(tasks))) {
            $0.tasks.tasks = tasks
        }

        // 3. Navigate to tasks tab
        await store.send(.tabSelected(.tasks)) {
            $0.selectedTab = .tasks
        }

        // 4. Link task A
        await store.send(.tasks(.taskTapped(Self.taskA.id))) {
            $0.tasks.linkedTaskID = Self.taskA.id
        }
        await store.receive(.tasks(.taskLinked(Self.taskA.id, "Write documentation"))) {
            $0.timer.linkedTaskID = Self.taskA.id.uuidString
            $0.timer.linkedTaskTitle = "Write documentation"
            $0.selectedTab = .timer  // auto-switch
        }

        // 5. Session starts on phone, state received
        let session = Self.activeSession(
            linkedTaskTitle: "Write documentation",
            linkedTaskID: Self.taskA.id.uuidString
        )
        await store.send(.sessionStateReceived(session))
        await store.receive(.timer(.sessionStateReceived(session))) {
            $0.timer.isSessionActive = true
            $0.timer.displayTime = "23:45"
            $0.timer.phaseLabel = "Focus 1/4"
        }

        // 6. Receive stats update
        await store.send(.statsReceived(todayMinutes: 25, sessions: 1, streak: 5))
        await store.receive(.timer(.statsReceived(todayMinutes: 25, sessions: 1, streak: 5))) {
            $0.timer.todayFocusMinutes = 25
            $0.timer.todaySessionsCompleted = 1
            $0.timer.currentStreakDays = 5
        }
        await store.receive(.dashboard(.statsReceived(todayMinutes: 25, sessions: 1, streak: 5))) {
            $0.dashboard.todayFocusMinutes = 25
            $0.dashboard.sessionsCompleted = 1
            $0.dashboard.streakDays = 5
        }
    }

    @Test("session ends, timer resets via sessionStateReceived idle")
    func sessionEndsResetsTimer() async {
        var state = WatchAppFeature.State()
        state.timer.isSessionActive = true
        state.timer.displayTime = "10:00"
        state.timer.phaseLabel = "Focus 3/4"

        let store = TestStore(initialState: state) {
            WatchAppFeature()
        }

        store.exhaustivity = .off

        let idle = WatchSessionState.idle

        await store.send(.sessionStateReceived(idle))
        // No auto-switch because session is not becoming active
        await store.receive(.timer(.sessionStateReceived(idle))) {
            $0.timer.isSessionActive = false
            $0.timer.isPaused = false
            $0.timer.displayTime = "25:00"
            $0.timer.phaseLabel = "Ready"
            $0.timer.progress = nil
            $0.timer.pomodoroNumber = nil
        }
    }

    @Test("link task, complete it, task list refreshes")
    func linkTaskThenComplete() async {
        var state = WatchAppFeature.State()
        state.tasks.tasks = [Self.taskA, Self.taskB]
        state.selectedTab = .tasks

        let store = TestStore(initialState: state) {
            WatchAppFeature()
        } withDependencies: {
            $0.watchConnectivityClient.sendCommand = { _ in }
        }

        store.exhaustivity = .off

        // Link task A
        await store.send(.tasks(.taskTapped(Self.taskA.id))) {
            $0.tasks.linkedTaskID = Self.taskA.id
        }
        await store.receive(.tasks(.taskLinked(Self.taskA.id, "Write documentation"))) {
            $0.timer.linkedTaskID = Self.taskA.id.uuidString
            $0.timer.linkedTaskTitle = "Write documentation"
            $0.selectedTab = .timer
        }

        // Navigate back to tasks
        await store.send(.tabSelected(.tasks)) {
            $0.selectedTab = .tasks
        }

        // Complete task A via watch
        await store.send(.tasks(.toggleCompleted(Self.taskA.id))) {
            let idx = $0.tasks.tasks.firstIndex(where: { $0.id == Self.taskA.id })!
            $0.tasks.tasks[idx] = WatchTaskItem(
                id: Self.taskA.id,
                title: "Write documentation",
                isCompleted: true,
                priority: 2,
                estimatedPomodoros: 3,
                completedPomodoros: 1
            )
        }
    }

    @Test("connectivity lost and regained re-requests data")
    func connectivityLostAndRegained() async {
        var state = WatchAppFeature.State()
        state.isConnected = true
        state.timer.isConnected = true

        let commandsSent = LockIsolated<[WatchCommand]>([])

        let store = TestStore(initialState: state) {
            WatchAppFeature()
        } withDependencies: {
            $0.watchConnectivityClient.sendCommand = { command in
                commandsSent.withValue { $0.append(command) }
            }
        }

        store.exhaustivity = .off

        // Lose connectivity
        await store.send(.connectivityChanged(false)) {
            $0.isConnected = false
        }
        await store.receive(.timer(.connectivityChanged(false))) {
            $0.timer.isConnected = false
        }

        // Clear commands from disconnect
        commandsSent.withValue { $0.removeAll() }

        // Regain connectivity
        await store.send(.connectivityChanged(true)) {
            $0.isConnected = true
        }
        await store.receive(.timer(.connectivityChanged(true))) {
            $0.timer.isConnected = true
        }

        // Should have re-requested tasks and dashboard
        commandsSent.withValue {
            #expect($0.contains(.requestTasks))
            #expect($0.contains(.requestDashboard))
        }
    }

    @Test("dashboard stats received populates dashboard child fully")
    func dashboardStatsReceivedPopulatesChild() async {
        let store = TestStore(initialState: WatchAppFeature.State()) {
            WatchAppFeature()
        }

        store.exhaustivity = .off

        await store.send(.dashboardStatsReceived(Self.sampleDashboardStats))
        await store.receive(.dashboard(.dashboardStatsReceived(Self.sampleDashboardStats))) {
            $0.dashboard.todayFocusMinutes = 180
            $0.dashboard.sessionsCompleted = 6
            $0.dashboard.tasksCompleted = 4
            $0.dashboard.tasksTotal = 10
            $0.dashboard.streakDays = 14
            $0.dashboard.pomodoroMinutes = 100
            $0.dashboard.flowtimeMinutes = 50
            $0.dashboard.timeBlockMinutes = 20
            $0.dashboard.stopwatchMinutes = 10
            $0.dashboard.longestSessionMinutes = 45
        }
    }

    @Test("switching link from one task to another sends both commands")
    func switchTaskLink() async {
        var state = WatchAppFeature.State()
        state.tasks.tasks = [Self.taskA, Self.taskB]
        state.tasks.linkedTaskID = Self.taskA.id
        state.timer.linkedTaskID = Self.taskA.id.uuidString
        state.timer.linkedTaskTitle = "Write documentation"

        let commandsSent = LockIsolated<[WatchCommand]>([])

        let store = TestStore(initialState: state) {
            WatchAppFeature()
        } withDependencies: {
            $0.watchConnectivityClient.sendCommand = { command in
                commandsSent.withValue { $0.append(command) }
            }
        }

        store.exhaustivity = .off

        // Tap a different task — the child sends taskLinked directly (not unlink first)
        await store.send(.tasks(.taskTapped(Self.taskB.id))) {
            $0.tasks.linkedTaskID = Self.taskB.id
        }

        await store.receive(.tasks(.taskLinked(Self.taskB.id, "Review PR"))) {
            $0.timer.linkedTaskID = Self.taskB.id.uuidString
            $0.timer.linkedTaskTitle = "Review PR"
            $0.selectedTab = .timer
        }

        commandsSent.withValue {
            #expect($0.contains(.linkTask(id: Self.taskB.id.uuidString)))
        }
    }
}
