// SessionJournalFeatureTests.swift
// Pepinillo — Deep Work Companion for Apple
//
// Tests for the post-session journal TCA reducer.

import Testing
import Foundation
import ComposableArchitecture
@testable import Pepinillo

@MainActor
struct SessionJournalFeatureTests {

    @Test("Note changes are capped at 500 characters")
    func testNoteCapped() async {
        let store = TestStore(
            initialState: SessionJournalFeature.State(
                sessionID: UUID(),
                modeName: "pomodoro",
                durationFormatted: "25:00"
            )
        ) {
            SessionJournalFeature()
        }

        let longText = String(repeating: "a", count: 600)
        await store.send(.noteChanged(longText)) {
            $0.journalNote = String(repeating: "a", count: 500)
        }
    }

    @Test("Rating toggles on re-select")
    func testRatingToggle() async {
        let store = TestStore(
            initialState: SessionJournalFeature.State(
                sessionID: UUID(),
                modeName: "flowtime",
                durationFormatted: "45:00"
            )
        ) {
            SessionJournalFeature()
        }

        await store.send(.ratingSelected(4)) {
            $0.satisfactionRating = 4
        }
        // Same rating again → deselect
        await store.send(.ratingSelected(4)) {
            $0.satisfactionRating = nil
        }
    }

    @Test("Save sends journal entry to persistence")
    func testSave() async {
        let sessionID = UUID()
        let savedValues = LockIsolated<(UUID?, String?, Int?)>((nil, nil, nil))

        let store = TestStore(
            initialState: SessionJournalFeature.State(
                sessionID: sessionID,
                modeName: "pomodoro",
                durationFormatted: "25:00",
                journalNote: "Great session",
                satisfactionRating: 5
            )
        ) {
            SessionJournalFeature()
        } withDependencies: {
            $0.persistenceClient.saveJournalEntry = { id, note, rating in
                savedValues.setValue((id, note, rating))
            }
        }

        await store.send(.saveTapped)
        await store.receive(\.saved)

        let (savedID, savedNote, savedRating) = savedValues.value
        #expect(savedID == sessionID)
        #expect(savedNote == "Great session")
        #expect(savedRating == 5)
    }

    @Test("Skip sends saved without persisting")
    func testSkip() async {
        let store = TestStore(
            initialState: SessionJournalFeature.State(
                sessionID: UUID(),
                modeName: "pomodoro",
                durationFormatted: "25:00"
            )
        ) {
            SessionJournalFeature()
        }

        await store.send(.skipTapped)
        await store.receive(\.saved)
    }
}
