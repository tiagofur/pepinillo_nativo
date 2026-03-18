// FocusSessionRecord+DTO.swift
// Pepinillo — Deep Work Companion for Apple
//
// Extension to convert SwiftData @Model to value-type DTO
// for use in App Intents (Siri / Apple Intelligence).

import Foundation

extension FocusSessionRecord {
    func toDTO() -> SessionRecordDTO {
        SessionRecordDTO(
            id: id,
            startedAt: startedAt,
            mode: mode,
            actualDuration: actualDuration,
            wasCompleted: wasCompleted,
            interruptions: interruptions,
            taskID: task?.id,
            journalNote: journalNote,
            satisfactionRating: satisfactionRating
        )
    }
}
