// SessionJournalFeature.swift
// Pepinillo — Deep Work Companion for Apple
//
// TCA Reducer for the post-session journal sheet.
// Appears after a focus session completes, allowing the user to
// rate satisfaction (emoji scale) and add a brief reflection note.

import Foundation
import ComposableArchitecture

@Reducer
struct SessionJournalFeature {

    @ObservableState
    struct State: Equatable {
        let sessionID: UUID
        let modeName: String
        let durationFormatted: String
        var journalNote: String = ""
        var satisfactionRating: Int? = nil   // 1-5
    }

    enum Action: Equatable {
        case noteChanged(String)
        case ratingSelected(Int)
        case saveTapped
        case skipTapped
        case saved
    }

    @Dependency(\.persistenceClient) var persistence

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .noteChanged(let text):
                state.journalNote = String(text.prefix(500))
                return .none

            case .ratingSelected(let rating):
                if state.satisfactionRating == rating {
                    state.satisfactionRating = nil
                } else {
                    state.satisfactionRating = rating
                }
                return .none

            case .saveTapped:
                let id = state.sessionID
                let note = state.journalNote.isEmpty ? nil : state.journalNote
                let rating = state.satisfactionRating
                return .run { send in
                    try await persistence.saveJournalEntry(id, note, rating)
                    await send(.saved)
                }

            case .skipTapped:
                return .send(.saved)

            case .saved:
                return .none
            }
        }
    }
}
