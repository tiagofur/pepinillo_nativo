// WeeklyReportService.swift
// Pepinillo — Deep Work Companion for Apple
//
// Pure computation: takes current + previous week sessions and produces
// a WeeklyReportData value. Used by both WeeklyReviewFeature (TCA) and
// GetWeeklyReportIntent (Siri / Apple Intelligence).

import Foundation

struct WeeklyReportData: Equatable, Sendable {
    let currentWeekMinutes: Int
    let currentWeekSessions: Int
    let previousWeekMinutes: Int
    let previousWeekSessions: Int
    let dominantMode: FocusMode?
    let bestDayName: String?
    let bestDayMinutes: Int
    let completionRate: Double
    let currentStreakDays: Int

    var minutesDelta: Int { currentWeekMinutes - previousWeekMinutes }
    var sessionsDelta: Int { currentWeekSessions - previousWeekSessions }
    var isImproving: Bool { minutesDelta > 0 }
}

struct WeeklyReportService: Sendable {

    func computeWeeklyReport(
        currentWeekSessions: [SessionRecordDTO],
        previousWeekSessions: [SessionRecordDTO],
        currentStreakDays: Int
    ) -> WeeklyReportData {
        // Current week aggregation
        var currentTotal = 0
        var currentCompleted = 0
        var modeSecs: [FocusMode: Int] = [:]
        var dailyMinutes: [String: Int] = [:]
        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "EEEE"

        for record in currentWeekSessions {
            let secs = Int(record.actualDuration)
            currentTotal += secs
            if record.wasCompleted { currentCompleted += 1 }
            if let mode = FocusMode(rawValue: record.mode) {
                modeSecs[mode, default: 0] += secs
            }
            let dayName = dayFormatter.string(from: record.startedAt)
            dailyMinutes[dayName, default: 0] += secs / 60
        }

        // Previous week
        var prevTotal = 0
        for record in previousWeekSessions {
            prevTotal += Int(record.actualDuration)
        }

        // Best day
        let best = dailyMinutes.max(by: { $0.value < $1.value })
        let dominant = modeSecs.max(by: { $0.value < $1.value })?.key
        let completionRate = currentWeekSessions.isEmpty ? 0.0
            : Double(currentCompleted) / Double(currentWeekSessions.count)

        return WeeklyReportData(
            currentWeekMinutes: currentTotal / 60,
            currentWeekSessions: currentWeekSessions.count,
            previousWeekMinutes: prevTotal / 60,
            previousWeekSessions: previousWeekSessions.count,
            dominantMode: dominant,
            bestDayName: best?.key,
            bestDayMinutes: best?.value ?? 0,
            completionRate: completionRate,
            currentStreakDays: currentStreakDays
        )
    }
}
