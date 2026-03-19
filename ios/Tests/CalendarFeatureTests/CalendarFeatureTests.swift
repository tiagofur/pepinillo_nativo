// CalendarFeatureTests.swift
// Pepinillo — Deep Work Companion for Apple
//
// TCA TestStore tests for CalendarFeature: month navigation,
// day selection, activity dot loading, day detail display.

import Testing
import Foundation
import ComposableArchitecture
@testable import Pepinillo

@Suite("CalendarFeature")
@MainActor
struct CalendarFeatureTests {

    // MARK: - Helpers

    private nonisolated func startOfCurrentMonth() -> Date {
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month], from: Date.now)
        return cal.date(from: comps) ?? Date.now
    }

    private nonisolated func date(year: Int, month: Int, day: Int) -> Date {
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        comps.day = day
        return Calendar.current.date(from: comps) ?? Date.now
    }

    private nonisolated func makeSession(
        id: UUID = UUID(),
        startedAt: Date,
        mode: String = "pomodoro",
        durationSeconds: TimeInterval = 1500,
        wasCompleted: Bool = true
    ) -> SessionRecordDTO {
        SessionRecordDTO(
            id: id,
            startedAt: startedAt,
            mode: mode,
            actualDuration: durationSeconds,
            wasCompleted: wasCompleted,
            interruptions: 0,
            taskID: nil
        )
    }

    private nonisolated func makeTask(
        id: UUID = UUID(),
        title: String = "Test Task",
        isCompleted: Bool = false,
        dueDate: Date? = nil,
        completedAt: Date? = nil
    ) -> TaskItemDTO {
        TaskItemDTO(
            id: id,
            title: title,
            isCompleted: isCompleted,
            dueDate: dueDate,
            completedAt: completedAt
        )
    }

    // MARK: - Default State

    @Test("Default state starts with current month and no selection")
    func testDefaultState() {
        let state = CalendarFeature.State()
        #expect(state.selectedDate == nil)
        #expect(state.isLoading == false)
        #expect(state.activityDays.isEmpty)
        #expect(state.selectedDayDetail == nil)
    }

    // MARK: - onAppear

    @Test("onAppear sets loading and fetches month data")
    func testOnAppear() async {
        let store = TestStore(initialState: CalendarFeature.State()) {
            CalendarFeature()
        } withDependencies: {
            $0.persistenceClient.fetchSessions = { _, _ in [] }
            $0.persistenceClient.fetchTasks = { [] }
        }
        store.exhaustivity = .off

        await store.send(.onAppear) {
            $0.isLoading = true
        }

        await store.receive(\.monthDataLoaded) {
            $0.isLoading = false
            $0.activityDays = []
        }
    }

    @Test("onAppear does nothing when already loading")
    func testOnAppearGuard() async {
        var state = CalendarFeature.State()
        state.isLoading = true

        let store = TestStore(initialState: state) {
            CalendarFeature()
        } withDependencies: {
            $0.persistenceClient.fetchSessions = { _, _ in [] }
            $0.persistenceClient.fetchTasks = { [] }
        }

        await store.send(.onAppear)
        // No state mutation — guard blocks
    }

    // MARK: - Month Navigation

    @Test("Month change updates displayed month and clears selection")
    func testMonthChanged() async {
        var state = CalendarFeature.State()
        state.selectedDate = Date.now
        state.selectedDayDetail = CalendarFeature.State.DayDetail(
            date: Date.now,
            totalFocusMinutes: 25,
            sessionsCompleted: 1,
            sessions: [],
            tasks: []
        )

        let nextMonth = Calendar.current.date(byAdding: .month, value: 1, to: state.displayedMonth)!

        let store = TestStore(initialState: state) {
            CalendarFeature()
        } withDependencies: {
            $0.persistenceClient.fetchSessions = { _, _ in [] }
            $0.persistenceClient.fetchTasks = { [] }
        }
        store.exhaustivity = .off

        await store.send(.monthChanged(nextMonth)) {
            $0.displayedMonth = nextMonth
            $0.selectedDate = nil
            $0.selectedDayDetail = nil
            $0.isLoading = true
        }

        await store.receive(\.monthDataLoaded) {
            $0.isLoading = false
        }
    }

    // MARK: - Activity Days

    @Test("Month data marks days with sessions")
    func testMonthDataWithSessions() async {
        let targetDate = date(year: 2026, month: 3, day: 10)
        let monthStart = date(year: 2026, month: 3, day: 1)
        let session = makeSession(startedAt: targetDate)

        var state = CalendarFeature.State()
        state.displayedMonth = monthStart

        let store = TestStore(initialState: state) {
            CalendarFeature()
        } withDependencies: {
            let sess = [session]
            $0.persistenceClient.fetchSessions = { _, _ in sess }
            $0.persistenceClient.fetchTasks = { [] }
        }
        store.exhaustivity = .off

        await store.send(.onAppear) {
            $0.isLoading = true
        }

        await store.receive(\.monthDataLoaded) {
            $0.isLoading = false
            let expected = Calendar.current.dateComponents([.year, .month, .day], from: targetDate)
            #expect($0.activityDays.contains(expected))
        }
    }

    @Test("Month data marks days with tasks due")
    func testMonthDataWithTasksDue() async {
        let dueDate = date(year: 2026, month: 3, day: 15)
        let monthStart = date(year: 2026, month: 3, day: 1)
        let task = makeTask(title: "Due Task", dueDate: dueDate)

        var state = CalendarFeature.State()
        state.displayedMonth = monthStart

        let store = TestStore(initialState: state) {
            CalendarFeature()
        } withDependencies: {
            let tasks = [task]
            $0.persistenceClient.fetchSessions = { _, _ in [] }
            $0.persistenceClient.fetchTasks = { tasks }
        }
        store.exhaustivity = .off

        await store.send(.onAppear) {
            $0.isLoading = true
        }

        await store.receive(\.monthDataLoaded) {
            $0.isLoading = false
            let expected = Calendar.current.dateComponents([.year, .month, .day], from: dueDate)
            #expect($0.activityDays.contains(expected))
        }
    }

    @Test("Empty month produces no activity days")
    func testEmptyMonthNoActivity() async {
        let store = TestStore(initialState: CalendarFeature.State()) {
            CalendarFeature()
        } withDependencies: {
            $0.persistenceClient.fetchSessions = { _, _ in [] }
            $0.persistenceClient.fetchTasks = { [] }
        }
        store.exhaustivity = .off

        await store.send(.onAppear) {
            $0.isLoading = true
        }

        await store.receive(\.monthDataLoaded) {
            $0.isLoading = false
            $0.activityDays = []
        }
    }

    // MARK: - Day Selection

    @Test("Day selection updates selectedDate and loads detail")
    func testDaySelected() async {
        let selectedDay = date(year: 2026, month: 3, day: 12)

        let store = TestStore(initialState: CalendarFeature.State()) {
            CalendarFeature()
        } withDependencies: {
            $0.persistenceClient.fetchSessions = { _, _ in [] }
            $0.persistenceClient.fetchTasks = { [] }
        }
        store.exhaustivity = .off

        await store.send(.daySelected(selectedDay)) {
            $0.selectedDate = selectedDay
        }

        await store.receive(\.dayDetailLoaded) {
            $0.selectedDayDetail = CalendarFeature.State.DayDetail(
                date: selectedDay,
                totalFocusMinutes: 0,
                sessionsCompleted: 0,
                sessions: [],
                tasks: []
            )
        }
    }

    // MARK: - Day Detail Loading

    @Test("Day detail aggregates sessions and tasks correctly")
    func testDayDetailAggregation() async {
        let targetDay = date(year: 2026, month: 3, day: 10)
        let sessionID = UUID()
        let taskID = UUID()

        let session = makeSession(
            id: sessionID,
            startedAt: targetDay.addingTimeInterval(3600),
            mode: "pomodoro",
            durationSeconds: 1500,
            wasCompleted: true
        )

        let task = makeTask(
            id: taskID,
            title: "Daily Task",
            isCompleted: true,
            dueDate: targetDay,
            completedAt: targetDay
        )

        let store = TestStore(initialState: CalendarFeature.State()) {
            CalendarFeature()
        } withDependencies: {
            let sessions = [session]
            let tasks = [task]
            $0.persistenceClient.fetchSessions = { _, _ in sessions }
            $0.persistenceClient.fetchTasks = { tasks }
        }
        store.exhaustivity = .off

        await store.send(.daySelected(targetDay)) {
            $0.selectedDate = targetDay
        }

        await store.receive(\.dayDetailLoaded) {
            let detail = $0.selectedDayDetail
            #expect(detail != nil)
            #expect(detail?.totalFocusMinutes == 25) // 1500s / 60
            #expect(detail?.sessionsCompleted == 1)
            #expect(detail?.sessions.count == 1)
            #expect(detail?.tasks.count == 1)
            #expect(detail?.tasks.first?.title == "Daily Task")
            #expect(detail?.tasks.first?.isDue == true)
            #expect(detail?.tasks.first?.wasCompletedToday == true)
        }
    }

    @Test("Day detail excludes tasks not due or completed on that day")
    func testDayDetailExcludesIrrelevantTasks() async {
        let targetDay = date(year: 2026, month: 3, day: 10)
        let otherDay = date(year: 2026, month: 3, day: 20)

        // Task due on a different day
        let task = makeTask(title: "Other Task", dueDate: otherDay)

        let store = TestStore(initialState: CalendarFeature.State()) {
            CalendarFeature()
        } withDependencies: {
            let tasks = [task]
            $0.persistenceClient.fetchSessions = { _, _ in [] }
            $0.persistenceClient.fetchTasks = { tasks }
        }
        store.exhaustivity = .off

        await store.send(.daySelected(targetDay)) {
            $0.selectedDate = targetDay
        }

        await store.receive(\.dayDetailLoaded) {
            #expect($0.selectedDayDetail?.tasks.isEmpty == true)
        }
    }

    // MARK: - monthDataLoaded directly

    @Test("monthDataLoaded sets activity days and clears loading")
    func testMonthDataLoadedDirectly() async {
        var state = CalendarFeature.State()
        state.isLoading = true

        let dayComps = DateComponents(year: 2026, month: 3, day: 5)

        let store = TestStore(initialState: state) {
            CalendarFeature()
        }

        await store.send(.monthDataLoaded([dayComps])) {
            $0.isLoading = false
            $0.activityDays = [dayComps]
        }
    }

    // MARK: - dayDetailLoaded directly

    @Test("dayDetailLoaded sets the selected day detail")
    func testDayDetailLoadedDirectly() async {
        let detail = CalendarFeature.State.DayDetail(
            date: Date.now,
            totalFocusMinutes: 90,
            sessionsCompleted: 3,
            sessions: [],
            tasks: []
        )

        let store = TestStore(initialState: CalendarFeature.State()) {
            CalendarFeature()
        }

        await store.send(.dayDetailLoaded(detail)) {
            $0.selectedDayDetail = detail
        }
    }

    // MARK: - Multiple Sessions in Day Detail

    @Test("Day detail sums multiple sessions correctly")
    func testDayDetailMultipleSessions() async {
        let targetDay = date(year: 2026, month: 3, day: 10)

        let session1 = makeSession(
            startedAt: targetDay.addingTimeInterval(3600),
            durationSeconds: 1500,
            wasCompleted: true
        )
        let session2 = makeSession(
            startedAt: targetDay.addingTimeInterval(7200),
            durationSeconds: 3000,
            wasCompleted: false
        )

        let store = TestStore(initialState: CalendarFeature.State()) {
            CalendarFeature()
        } withDependencies: {
            let sessions = [session1, session2]
            $0.persistenceClient.fetchSessions = { _, _ in sessions }
            $0.persistenceClient.fetchTasks = { [] }
        }
        store.exhaustivity = .off

        await store.send(.daySelected(targetDay)) {
            $0.selectedDate = targetDay
        }

        await store.receive(\.dayDetailLoaded) {
            let detail = $0.selectedDayDetail
            #expect(detail?.totalFocusMinutes == 75) // (1500 + 3000) / 60
            #expect(detail?.sessionsCompleted == 1)  // only session1 was completed
            #expect(detail?.sessions.count == 2)
        }
    }
}
