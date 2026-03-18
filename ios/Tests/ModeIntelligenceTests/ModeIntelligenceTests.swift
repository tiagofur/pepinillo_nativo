// ModeIntelligenceTests.swift
// Pepinillo — Deep Work Companion for Apple
//
// Tests for ModeIntelligenceService: mode suggestion scoring,
// confidence thresholds, margin requirements, and energy level analysis.
// Uses SessionRecordDTO value types — no SwiftData container needed.

import Testing
import Foundation
@testable import Pepinillo

@Suite("ModeIntelligenceService")
struct ModeIntelligenceTests {

    private let service = ModeIntelligenceService()

    // MARK: - Helpers

    /// Creates a SessionRecordDTO with the given parameters.
    private func makeSessionDTO(
        mode: FocusMode,
        duration: TimeInterval,
        wasCompleted: Bool,
        taskID: UUID
    ) -> SessionRecordDTO {
        SessionRecordDTO(
            id: UUID(),
            startedAt: Date(),
            mode: mode.rawValue,
            actualDuration: duration,
            wasCompleted: wasCompleted,
            interruptions: 0,
            taskID: taskID
        )
    }

    // MARK: - suggestMode(forTaskID:) — Minimum Session Guard

    @Test("Returns nil when session count is below minimum")
    func returnsNilWhenBelowMinimumSessions() throws {
        let taskID = UUID()

        // Only 2 sessions, minimum is 3
        let sessions = [
            makeSessionDTO(mode: .pomodoro, duration: 1500, wasCompleted: true, taskID: taskID),
            makeSessionDTO(mode: .pomodoro, duration: 1500, wasCompleted: true, taskID: taskID),
        ]

        let suggestion = service.suggestMode(
            forTaskID: taskID,
            sessions: sessions,
            minimumSessions: 3
        )
        #expect(suggestion == nil)
    }

    @Test("Returns nil when all sessions belong to a different task")
    func returnsNilForWrongTaskID() throws {
        let task1ID = UUID()
        let task2ID = UUID()

        // 5 sessions for task2 only
        let sessions = (0..<5).map { _ in
            makeSessionDTO(mode: .pomodoro, duration: 1500, wasCompleted: true, taskID: task2ID)
        }

        // Query with task1ID → filtered out → below minimum → nil
        let suggestion = service.suggestMode(
            forTaskID: task1ID,
            sessions: sessions,
            minimumSessions: 3
        )
        #expect(suggestion == nil)
    }

    @Test("Returns nil when no sessions were completed")
    func returnsNilWhenNoCompletedSessions() throws {
        let taskID = UUID()

        // 5 sessions but all abandoned (wasCompleted = false)
        let sessions = (0..<5).map { _ in
            makeSessionDTO(mode: .pomodoro, duration: 300, wasCompleted: false, taskID: taskID)
        }

        let suggestion = service.suggestMode(
            forTaskID: taskID,
            sessions: sessions,
            minimumSessions: 3
        )
        #expect(suggestion == nil)
    }

    // MARK: - suggestMode(forTaskID:) — Dominant Mode Detection

    @Test("Suggests dominant mode when one mode has clear majority")
    func suggestsDominantMode() throws {
        let taskID = UUID()

        // 5 Pomodoro sessions (all complete) — clear dominant mode
        let sessions = (0..<5).map { _ in
            makeSessionDTO(mode: .pomodoro, duration: 1500, wasCompleted: true, taskID: taskID)
        }

        let suggestion = service.suggestMode(
            forTaskID: taskID,
            sessions: sessions,
            minimumSessions: 3
        )
        #expect(suggestion != nil)
        #expect(suggestion?.suggestedMode == .pomodoro)
    }

    @Test("Filters sessions correctly and only considers the queried task")
    func filtersSessionsByTaskID() throws {
        let task1ID = UUID()
        let task2ID = UUID()

        // task1 → 3 Pomodoro; task2 → 3 Flowtime
        let allSessions = (0..<3).map { _ in
            makeSessionDTO(mode: .pomodoro, duration: 1500, wasCompleted: true, taskID: task1ID)
        } + (0..<3).map { _ in
            makeSessionDTO(mode: .flowtime, duration: 1800, wasCompleted: true, taskID: task2ID)
        }

        // For task1, should recommend Pomodoro (task2's Flowtime sessions are ignored)
        let suggestion = service.suggestMode(
            forTaskID: task1ID,
            sessions: allSessions,
            minimumSessions: 3
        )
        #expect(suggestion?.suggestedMode == .pomodoro)
    }

    // MARK: - suggestMode(forTaskID:) — Confidence & Margin Thresholds

    @Test("Returns nil when completion rate is below 70% threshold")
    func returnsNilWhenCompletionRateBelowThreshold() throws {
        let taskID = UUID()

        // Pomodoro: 2 of 4 completed = 50% → below 70%
        let sessions = [
            makeSessionDTO(mode: .pomodoro, duration: 1500, wasCompleted: true, taskID: taskID),
            makeSessionDTO(mode: .pomodoro, duration: 1500, wasCompleted: true, taskID: taskID),
            makeSessionDTO(mode: .pomodoro, duration: 1500, wasCompleted: false, taskID: taskID),
            makeSessionDTO(mode: .pomodoro, duration: 1500, wasCompleted: false, taskID: taskID),
        ]

        let suggestion = service.suggestMode(
            forTaskID: taskID,
            sessions: sessions,
            minimumSessions: 3
        )
        #expect(suggestion == nil)
    }

    @Test("Returns nil when two modes have similar scores (margin < 10%)")
    func returnsNilWhenMarginsAreTooClose() throws {
        let taskID = UUID()

        // Pomodoro and Flowtime both: 3 completed with same duration → tied scores → margin = 0
        let sessions = (0..<3).map { _ in
            makeSessionDTO(mode: .pomodoro, duration: 1500, wasCompleted: true, taskID: taskID)
        } + (0..<3).map { _ in
            makeSessionDTO(mode: .flowtime, duration: 1500, wasCompleted: true, taskID: taskID)
        }

        let suggestion = service.suggestMode(
            forTaskID: taskID,
            sessions: sessions,
            minimumSessions: 3
        )
        #expect(suggestion == nil)
    }

    @Test("Suggestion confidence is within 0.0–1.0 range")
    func suggestionConfidenceIsInValidRange() throws {
        let taskID = UUID()

        // Single dominant mode with perfect completion
        var sessions = (0..<5).map { _ in
            makeSessionDTO(mode: .pomodoro, duration: 1500, wasCompleted: true, taskID: taskID)
        }
        // Add a weak competing mode to create margin
        sessions.append(makeSessionDTO(mode: .flowtime, duration: 100, wasCompleted: false, taskID: taskID))

        if let suggestion = service.suggestMode(
            forTaskID: taskID,
            sessions: sessions,
            minimumSessions: 3
        ) {
            #expect(suggestion.confidence >= 0.0)
            #expect(suggestion.confidence <= 1.0)
        }
    }

    @Test("Suggestion includes a non-empty reason string")
    func suggestionIncludesReason() throws {
        let taskID = UUID()

        var sessions = (0..<5).map { _ in
            makeSessionDTO(mode: .pomodoro, duration: 1500, wasCompleted: true, taskID: taskID)
        }
        sessions.append(makeSessionDTO(mode: .flowtime, duration: 100, wasCompleted: false, taskID: taskID))

        if let suggestion = service.suggestMode(
            forTaskID: taskID,
            sessions: sessions,
            minimumSessions: 3
        ) {
            #expect(!suggestion.reason.isEmpty)
        }
    }

    // MARK: - suggestModeForEnergyLevel — Minimum Session Guard

    @Test("Energy level: returns nil when below minimum sessions")
    func energyLevelReturnsNilBelowMinimum() throws {
        let taskID = UUID()

        // Only 3 sessions, minimum is 5
        let sessions = (0..<3).map { _ in
            makeSessionDTO(mode: .pomodoro, duration: 1500, wasCompleted: true, taskID: taskID)
        }

        let suggestion = service.suggestModeForEnergyLevel(
            .deep,
            sessions: sessions,
            taskIDs: [taskID],
            minimumSessions: 5
        )
        #expect(suggestion == nil)
    }

    @Test("Energy level: returns suggestion with sufficient sessions")
    func energyLevelReturnsSuggestionWhenSufficient() throws {
        let taskID = UUID()

        // 5 completed sessions — meets minimum
        let sessions = (0..<5).map { _ in
            makeSessionDTO(mode: .pomodoro, duration: 1500, wasCompleted: true, taskID: taskID)
        }

        let suggestion = service.suggestModeForEnergyLevel(
            .deep,
            sessions: sessions,
            taskIDs: [taskID],
            minimumSessions: 5
        )
        #expect(suggestion != nil)
    }

    @Test("Energy level: filters out sessions from wrong energy level tasks")
    func energyLevelFiltersByTaskEnergyLevel() throws {
        let deepTaskID = UUID()
        let shallowTaskID = UUID()

        // 5 sessions for deep tasks only
        let deepSessions = (0..<5).map { _ in
            makeSessionDTO(mode: .pomodoro, duration: 1500, wasCompleted: true, taskID: deepTaskID)
        }
        // Only 2 sessions for shallow tasks — below minimum
        let shallowSessions = (0..<2).map { _ in
            makeSessionDTO(mode: .flowtime, duration: 900, wasCompleted: true, taskID: shallowTaskID)
        }
        let allSessions = deepSessions + shallowSessions

        // Querying .shallow — only 2 relevant sessions → below min of 5 → nil
        let shallowSuggestion = service.suggestModeForEnergyLevel(
            .shallow,
            sessions: allSessions,
            taskIDs: [shallowTaskID],
            minimumSessions: 5
        )
        #expect(shallowSuggestion == nil)

        // Querying .deep — 5 relevant sessions → should return a suggestion
        let deepSuggestion = service.suggestModeForEnergyLevel(
            .deep,
            sessions: allSessions,
            taskIDs: [deepTaskID],
            minimumSessions: 5
        )
        #expect(deepSuggestion != nil)
    }

    @Test("Energy level: returns nil when completion rate below 70%")
    func energyLevelReturnsNilForLowCompletionRate() throws {
        let taskID = UUID()

        // 5 sessions, only 2 completed = 40% → below 70%
        let sessions = [
            makeSessionDTO(mode: .pomodoro, duration: 1500, wasCompleted: true, taskID: taskID),
            makeSessionDTO(mode: .pomodoro, duration: 1500, wasCompleted: true, taskID: taskID),
            makeSessionDTO(mode: .pomodoro, duration: 1500, wasCompleted: false, taskID: taskID),
            makeSessionDTO(mode: .pomodoro, duration: 1500, wasCompleted: false, taskID: taskID),
            makeSessionDTO(mode: .pomodoro, duration: 1500, wasCompleted: false, taskID: taskID),
        ]

        let suggestion = service.suggestModeForEnergyLevel(
            .admin,
            sessions: sessions,
            taskIDs: [taskID],
            minimumSessions: 5
        )
        #expect(suggestion == nil)
    }

    @Test("Energy level suggestion has confidence in valid range")
    func energyLevelSuggestionConfidenceInRange() throws {
        let taskID = UUID()

        let sessions = (0..<5).map { _ in
            makeSessionDTO(mode: .stopwatch, duration: 600, wasCompleted: true, taskID: taskID)
        }

        if let suggestion = service.suggestModeForEnergyLevel(
            .shallow,
            sessions: sessions,
            taskIDs: [taskID],
            minimumSessions: 5
        ) {
            #expect(suggestion.confidence >= 0.0)
            #expect(suggestion.confidence <= 1.0)
            #expect(!suggestion.reason.isEmpty)
        }
    }
}
