// GetModeSuggestionIntent.swift
// Pepinillo — Deep Work Companion for Apple
//
// Siri / Apple Intelligence intent: "What focus mode should I use in Pepinillo?"
// Uses ModeIntelligenceService to suggest the best mode based on history.

import AppIntents
import Foundation
import SwiftData

struct GetModeSuggestionIntent: AppIntent {
    static let title: LocalizedStringResource = "Suggest Focus Mode"
    static let description = IntentDescription(
        "Get a personalized focus mode suggestion based on your productivity patterns.",
        categoryName: "Focus"
    )
    static let openAppWhenRun: Bool = false

    @Parameter(title: "Task")
    var task: TaskEntity?

    static var parameterSummary: some ParameterSummary {
        Summary("Suggest a mode for \(\.$task)")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let container = try? makeIntentsModelContainer() else {
            return .result(dialog: "I couldn't access your focus data right now.")
        }

        let context = ModelContext(container)
        let calendar = Calendar.current
        let today = Date.now

        guard let start = calendar.date(byAdding: .day, value: -30, to: today) else {
            return .result(dialog: "I couldn't compute the date range.")
        }

        // Fetch last 30 days of sessions
        let predicate = #Predicate<FocusSessionRecord> { $0.startedAt >= start }
        let records = (try? context.fetch(FetchDescriptor(predicate: predicate))) ?? []
        let sessions = records.map { $0.toDTO() }

        if sessions.count < 3 {
            return .result(dialog: "I need at least a few sessions to make a suggestion. Try Pomodoro to start — it's great for building focus habits!")
        }

        let service = ModeIntelligenceService()

        // If task provided, suggest for that task
        if let taskID = task?.id, let uuid = UUID(uuidString: taskID) {
            if let suggestion = service.suggestMode(forTaskID: uuid, sessions: sessions) {
                return .result(dialog: "For \(task?.title ?? "this task"), I'd suggest \(suggestion.suggestedMode.displayName). \(suggestion.reason)")
            }
        }

        // General suggestion based on time of day + overall patterns
        let hour = calendar.component(.hour, from: today)
        let generalSuggestion = suggestByTimeOfDay(hour: hour, sessions: sessions)
        return .result(dialog: "\(generalSuggestion)")
    }

    private func suggestByTimeOfDay(hour: Int, sessions: [SessionRecordDTO]) -> String {
        // Analyze which modes work best at this time of day
        let relevantSessions = sessions.filter { record in
            let h = Calendar.current.component(.hour, from: record.startedAt)
            return abs(h - hour) <= 2  // ±2 hour window
        }

        guard !relevantSessions.isEmpty else {
            if hour < 12 {
                return String(localized: "For a morning session, I'd suggest Pomodoro — structured intervals help build momentum early in the day.")
            } else if hour < 17 {
                return String(localized: "For an afternoon session, try Flowtime — let your natural rhythm guide the length.")
            } else {
                return String(localized: "For an evening session, try a Time Block — set a fixed duration to avoid going too late.")
            }
        }

        // Find mode with highest completion rate at this time
        var modeCompleted: [String: (completed: Int, total: Int)] = [:]
        for record in relevantSessions {
            var stats = modeCompleted[record.mode] ?? (0, 0)
            stats.total += 1
            if record.wasCompleted { stats.completed += 1 }
            modeCompleted[record.mode] = stats
        }

        if let best = modeCompleted.max(by: {
            let r1 = $0.value.total > 0 ? Double($0.value.completed) / Double($0.value.total) : 0
            let r2 = $1.value.total > 0 ? Double($1.value.completed) / Double($1.value.total) : 0
            return r1 < r2
        }) {
            let modeName = FocusMode(rawValue: best.key)?.displayName ?? best.key
            let rate = best.value.total > 0 ? Int(Double(best.value.completed) / Double(best.value.total) * 100) : 0
            return String(localized: "Based on your history around this time of day, I'd suggest \(modeName). You complete \(rate)% of \(modeName) sessions at this hour.")
        }

        return String(localized: "Try Pomodoro — it's a solid default for any time of day.")
    }
}
