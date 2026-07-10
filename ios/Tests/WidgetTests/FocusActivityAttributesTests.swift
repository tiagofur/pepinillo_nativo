// FocusActivityAttributesTests.swift
// Pepinillo — Deep Work Companion for Apple
//
// Unit tests for Live Activity content mapping (timer anchors, staleDate, initialContent).

import Foundation
import Testing
@testable import Pepinillo

@Suite("FocusActivityAttributesTests")
struct FocusActivityAttributesTests {
    private let referenceDate = Date(timeIntervalSince1970: 1_700_000_000)

    private func pomodoroState(
        elapsed: TimeInterval = 120,
        remaining: TimeInterval = 1_380,
        isPaused: Bool = false,
        totalPomodoros: Int = 4
    ) -> FocusSessionState {
        FocusSessionState(
            id: UUID(),
            mode: .pomodoro,
            phase: .work(number: 2, total: totalPomodoros),
            startedAt: referenceDate.addingTimeInterval(-elapsed),
            elapsedSeconds: elapsed,
            targetDuration: 25 * 60,
            remainingSeconds: remaining,
            progress: elapsed / (25 * 60),
            isPaused: isPaused,
            pomodoroNumber: 2,
            totalPomodoros: totalPomodoros
        )
    }

    @Test("initialContent preserves elapsed, pomodoros, and pause state")
    func initialContentUsesLiveSessionValues() {
        let state = pomodoroState(elapsed: 90, remaining: 1_410, isPaused: true, totalPomodoros: 6)
        let content = FocusActivityAttributes.initialContent(from: state)

        #expect(content.elapsedSeconds == 90)
        #expect(content.remainingSeconds == 1_410)
        #expect(content.totalPomodoros == 6)
        #expect(content.pomodoroNumber == 2)
        #expect(content.isPaused == true)
        #expect(content.timerStart == nil)
        #expect(content.timerEnd == nil)
    }

    @Test("timerAnchors for countdown modes derive start and end from elapsed and remaining")
    func countdownTimerAnchors() throws {
        let state = pomodoroState(elapsed: 60, remaining: 1_440)
        let now = referenceDate
        let anchors = FocusActivityAttributes.timerAnchors(from: state, now: now)

        let start = try #require(anchors.start)
        let end = try #require(anchors.end)
        #expect(end.timeIntervalSince(now) == 1_440)
        #expect(start.timeIntervalSince(now) == -60)
    }

    @Test("timerAnchors for count-up modes expose only a start anchor")
    func countUpTimerAnchors() throws {
        let state = FocusSessionState(
            id: UUID(),
            mode: .flowtime,
            phase: .flow,
            startedAt: referenceDate.addingTimeInterval(-300),
            elapsedSeconds: 300,
            remainingSeconds: nil,
            progress: nil
        )
        let anchors = FocusActivityAttributes.timerAnchors(from: state, now: referenceDate)

        let start = try #require(anchors.start)
        #expect(anchors.end == nil)
        #expect(start.timeIntervalSince(referenceDate) == -300)
    }

    @Test("staleDate for active countdown matches phase end")
    func staleDateMatchesPhaseEnd() throws {
        let state = pomodoroState(remaining: 900)
        let stale = try #require(FocusActivityAttributes.staleDate(for: state, now: referenceDate))
        #expect(stale.timeIntervalSince(referenceDate) == 900)
    }

    @Test("staleDate is nil when paused or count-up")
    func staleDateNilWhenPausedOrCountUp() {
        let paused = pomodoroState(isPaused: true)
        #expect(FocusActivityAttributes.staleDate(for: paused, now: referenceDate) == nil)

        let flow = FocusSessionState(
            id: UUID(),
            mode: .flowtime,
            phase: .flow,
            startedAt: referenceDate,
            elapsedSeconds: 10
        )
        #expect(FocusActivityAttributes.staleDate(for: flow, now: referenceDate) == nil)
    }
}