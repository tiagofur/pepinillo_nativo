// ReviewPromptTests.swift
// Pepinillo — Deep Work Companion for Apple
//
// Tests for the milestone review prompt gate (#979, parity with Android #716):
// after 3 completed sessions the app asks for a rating exactly once per
// device; task edits never trigger it; the manual About button always fires.

import Testing
import Foundation
import ComposableArchitecture
@testable import Pepinillo

@Suite("Review Prompt Gate", .serialized, .appGroupDefaultsSerialized)
@MainActor
struct ReviewPromptTests {

    // MARK: - Fixtures

    private func session(completed: Bool, id: UUID = UUID()) -> SessionRecordDTO {
        SessionRecordDTO(
            id: id,
            startedAt: Date.now.addingTimeInterval(-1_500),
            endedAt: Date.now,
            mode: "pomodoro",
            actualDuration: 1_500,
            wasCompleted: completed,
            interruptions: 0,
            taskID: nil
        )
    }

    /// Recorder for the review client — the OS call itself must not run in tests.
    private final class ReviewRecorder: @unchecked Sendable {
        private let lock = NSLock()
        private var count = 0
        func record() { lock.lock(); count += 1; lock.unlock() }
        var calls: Int { lock.lock(); defer { lock.unlock() }; return count }
    }

    private func configureDependencies(
        _ deps: inout DependencyValues,
        sessions: [SessionRecordDTO],
        recorder: ReviewRecorder
    ) {
        deps.persistenceClient.fetchSessions = { _, _ in sessions }
        deps.persistenceClient.fetchPreferences = { UserPreferencesDTO() }
        deps.persistenceClient.savePreferences = { _ in }
        deps.persistenceClient.fetchTasks = { [] }
        // The analytics refresh rides the same delegate path — stub every
        // aggregate it touches so the testValue "Unimplemented" issues don't
        // fail the test.
        deps.persistenceClient.fetchDailyStats = { _ in nil }
        deps.persistenceClient.fetchDailyStatsRange = { _, _ in [] }
        deps.persistenceClient.fetchSessionCount = { _ in 0 }
        deps.persistenceClient.fetchEarlyBirdSessionCount = { _ in 0 }
        deps.persistenceClient.fetchCompletedPomodoroCount = { _ in 0 }
        deps.persistenceClient.fetchCompletedFlowtimeCount = { _ in 0 }
        deps.persistenceClient.resolveAchievements = { _ in [] }
        deps.reviewClient.requestReview = { recorder.record() }
        deps.keychainClient.hasTokens = { false }
        deps.webSocketClient.connect = {}
        deps.webSocketClient.disconnect = {}
        deps.syncClient.syncAll = {}
    }

    // MARK: - Gate

    @Test("third completed session triggers the review prompt once")
    func thirdSessionTriggersPrompt() async {
        let recorder = ReviewRecorder()
        AppGroupDefaults.reviewRequestedMilestone = false
        defer { AppGroupDefaults.reviewRequestedMilestone = false }

        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: {
            configureDependencies(&$0, sessions: [
                session(completed: true),
                session(completed: true),
                session(completed: true),
            ], recorder: recorder)
        }
        store.exhaustivity = .off

        await store.send(.focus(.delegate(.sessionPersisted)))
        await store.finish()

        #expect(recorder.calls == 1)
        #expect(AppGroupDefaults.reviewRequestedMilestone == true)
    }

    @Test("below threshold no prompt fires")
    func belowThresholdNoPrompt() async {
        let recorder = ReviewRecorder()
        AppGroupDefaults.reviewRequestedMilestone = false
        defer { AppGroupDefaults.reviewRequestedMilestone = false }

        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: {
            configureDependencies(&$0, sessions: [
                session(completed: true),
                session(completed: true),
                session(completed: false),
            ], recorder: recorder)
        }
        store.exhaustivity = .off

        await store.send(.focus(.delegate(.sessionPersisted)))
        await store.finish()

        #expect(recorder.calls == 0)
        #expect(AppGroupDefaults.reviewRequestedMilestone == false)
    }

    @Test("already-prompted devices never prompt again")
    func alreadyPromptedNoRepeat() async {
        let recorder = ReviewRecorder()
        AppGroupDefaults.reviewRequestedMilestone = true
        defer { AppGroupDefaults.reviewRequestedMilestone = false }

        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: {
            configureDependencies(&$0, sessions: [
                session(completed: true),
                session(completed: true),
                session(completed: true),
                session(completed: true),
            ], recorder: recorder)
        }
        store.exhaustivity = .off

        await store.send(.focus(.delegate(.sessionPersisted)))
        await store.finish()

        #expect(recorder.calls == 0)
        #expect(AppGroupDefaults.reviewRequestedMilestone == true)
    }

    @Test("abandoned sessions do not count toward the threshold")
    func abandonedSessionsDoNotCount() async {
        let recorder = ReviewRecorder()
        AppGroupDefaults.reviewRequestedMilestone = false
        defer { AppGroupDefaults.reviewRequestedMilestone = false }

        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: {
            configureDependencies(&$0, sessions: [
                session(completed: false),
                session(completed: false),
                session(completed: false),
            ], recorder: recorder)
        }
        store.exhaustivity = .off

        await store.send(.focus(.delegate(.sessionPersisted)))
        await store.finish()

        #expect(recorder.calls == 0)
    }

    // MARK: - Manual button

    @Test("About rate button always requests review")
    func aboutRateButtonRequests() async {
        let recorder = ReviewRecorder()

        let store = TestStore(initialState: AboutFeature.State()) {
            AboutFeature()
        } withDependencies: {
            $0.reviewClient.requestReview = { recorder.record() }
        }

        await store.send(.rateAppTapped)

        #expect(recorder.calls == 1)
    }
}
