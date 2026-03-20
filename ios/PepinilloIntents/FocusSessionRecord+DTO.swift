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
            endedAt: endedAt,
            mode: mode,
            phase: phase,
            targetDuration: targetDuration,
            actualDuration: actualDuration,
            wasCompleted: wasCompleted,
            interruptions: interruptions,
            pauseCount: pauseCount,
            totalPauseDuration: totalPauseDuration,
            pomodoroNumber: pomodoroNumber,
            taskID: task?.id,
            journalNote: journalNote,
            satisfactionRating: satisfactionRating
        )
    }
}
