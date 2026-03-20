// ReportDataBuilder.swift
// Pepinillo — Deep Work Companion for Apple
//
// Assembles structured JSON payload from session and task data
// to send to the AI report generation endpoint.

import Foundation

// MARK: - Report Payload (sent to AI)

public struct ReportPayload: Codable, Sendable, Equatable {
    public let period: String
    public let periodStart: String
    public let periodEnd: String
    public let summary: Summary
    public let trends: Trends
    public let patterns: Patterns
    public let taskBreakdown: [TaskBreakdownItem]
    public let dailyDistribution: [DailyDistributionItem]

    public struct Summary: Codable, Sendable, Equatable {
        public let totalFocusMinutes: Int
        public let sessions: Int
        public let completedSessions: Int
        public let completionRate: Double
        public let interruptions: Int
        public let focusQualityScore: Int
    }

    public struct Trends: Codable, Sendable, Equatable {
        public let focusMinutesDelta: Int
        public let sessionsDelta: Int
        public let completionRateDelta: Double
    }

    public struct Patterns: Codable, Sendable, Equatable {
        public let peakHours: String
        public let bestDay: String
        public let dominantMode: String
        public let avgPausesPerSession: Double
    }

    public struct TaskBreakdownItem: Codable, Sendable, Equatable {
        public let title: String
        public let focusMinutes: Int
        public let sessions: Int
        public let completionRate: Double
        public let estimationAccuracy: Double?
    }

    public struct DailyDistributionItem: Codable, Sendable, Equatable {
        public let day: String
        public let focusMinutes: Int
        public let sessions: Int
    }
}

// MARK: - Report Period

enum ReportPeriod: String, Codable, Sendable, Equatable, CaseIterable {
    case week
    case month

    var days: Int {
        switch self {
        case .week: return 7
        case .month: return 30
        }
    }

    var displayName: String {
        switch self {
        case .week: return String(localized: "Weekly")
        case .month: return String(localized: "Monthly")
        }
    }
}

// MARK: - Builder

struct ReportDataBuilder: Sendable {

    /// Build a structured payload from session and task data for a given period.
    func buildPayload(
        period: ReportPeriod,
        currentSessions: [SessionRecordDTO],
        previousSessions: [SessionRecordDTO],
        tasks: [TaskItemDTO],
        calendar: Calendar = .current
    ) -> ReportPayload {
        let today = calendar.startOfDay(for: .now)
        let periodStart = calendar.date(byAdding: .day, value: -(period.days - 1), to: today) ?? today
        let periodEnd = today

        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withFullDate]

        // Summary
        let totalFocusSecs = currentSessions.reduce(0) { $0 + Int($1.actualDuration) }
        let completedCount = currentSessions.filter(\.wasCompleted).count
        let totalInterruptions = currentSessions.reduce(0) { $0 + $1.interruptions }
        let completionRate = currentSessions.isEmpty ? 0.0 : Double(completedCount) / Double(currentSessions.count)

        let totalPauses = currentSessions.reduce(0) { $0 + $1.pauseCount }
        let avgPauses = currentSessions.isEmpty ? 0.0 : Double(totalPauses) / Double(currentSessions.count)

        // Quality score: 60% completion + 40% low-interruption
        let avgInterruptions = currentSessions.isEmpty ? 0.0 : Double(totalInterruptions) / Double(currentSessions.count)
        let interruptionFactor = min(avgInterruptions / 3.0, 1.0)
        let focusQualityScore = Int(completionRate * 60.0 + (1.0 - interruptionFactor) * 40.0)

        let summary = ReportPayload.Summary(
            totalFocusMinutes: totalFocusSecs / 60,
            sessions: currentSessions.count,
            completedSessions: completedCount,
            completionRate: (completionRate * 100).rounded() / 100,
            interruptions: totalInterruptions,
            focusQualityScore: focusQualityScore
        )

        // Trends vs previous period
        let prevFocusSecs = previousSessions.reduce(0) { $0 + Int($1.actualDuration) }
        let prevCompleted = previousSessions.filter(\.wasCompleted).count
        let prevCompletionRate = previousSessions.isEmpty ? 0.0 : Double(prevCompleted) / Double(previousSessions.count)

        let trends = ReportPayload.Trends(
            focusMinutesDelta: (totalFocusSecs / 60) - (prevFocusSecs / 60),
            sessionsDelta: currentSessions.count - previousSessions.count,
            completionRateDelta: ((completionRate - prevCompletionRate) * 100).rounded() / 100
        )

        // Patterns
        var hourBuckets = [Int: Double]()
        var weekdayBuckets = [Int: Double]()
        var modeSecs = [String: Int]()

        for record in currentSessions {
            let hour = calendar.component(.hour, from: record.startedAt)
            hourBuckets[hour, default: 0] += record.actualDuration

            let weekday = calendar.component(.weekday, from: record.startedAt)
            weekdayBuckets[weekday, default: 0] += record.actualDuration

            modeSecs[record.mode, default: 0] += Int(record.actualDuration)
        }

        let peakHour = hourBuckets.max(by: { $0.value < $1.value })?.key
        let peakHoursStr: String
        if let ph = peakHour {
            let endHour = (ph + 2) % 24
            peakHoursStr = "\(ph):00-\(endHour):00"
        } else {
            peakHoursStr = ""
        }

        let bestWeekday = weekdayBuckets.max(by: { $0.value < $1.value })?.key
        let bestDayStr = bestWeekday.map { calendar.weekdaySymbols[$0 - 1] } ?? ""

        let dominantMode = modeSecs.max(by: { $0.value < $1.value })?.key ?? ""

        let patterns = ReportPayload.Patterns(
            peakHours: peakHoursStr,
            bestDay: bestDayStr,
            dominantMode: dominantMode,
            avgPausesPerSession: (avgPauses * 10).rounded() / 10
        )

        // Task breakdown
        let taskMap = Dictionary(uniqueKeysWithValues: tasks.map { ($0.id, $0) })
        var taskSessions = [UUID: [SessionRecordDTO]]()
        for record in currentSessions {
            if let taskID = record.taskID {
                taskSessions[taskID, default: []].append(record)
            }
        }

        let taskBreakdown: [ReportPayload.TaskBreakdownItem] = taskSessions
            .sorted(by: { $0.value.reduce(0) { $0 + Int($1.actualDuration) } > $1.value.reduce(0) { $0 + Int($1.actualDuration) } })
            .prefix(10)
            .map { taskID, sessions in
                let task = taskMap[taskID]
                let focusSecs = sessions.reduce(0) { $0 + Int($1.actualDuration) }
                let completed = sessions.filter(\.wasCompleted).count
                let rate = sessions.isEmpty ? 0.0 : Double(completed) / Double(sessions.count)

                var estimationAccuracy: Double?
                if let t = task, t.estimatedPomodoros > 0 && t.completedPomodoros > 0 {
                    estimationAccuracy = Double(t.completedPomodoros) / Double(t.estimatedPomodoros)
                }

                return ReportPayload.TaskBreakdownItem(
                    title: task?.title ?? String(localized: "Unknown Task"),
                    focusMinutes: focusSecs / 60,
                    sessions: sessions.count,
                    completionRate: (rate * 100).rounded() / 100,
                    estimationAccuracy: estimationAccuracy
                )
            }

        // Daily distribution
        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "EEE"

        var dailyMap = [Date: (Int, Int)]() // (seconds, sessions)
        for record in currentSessions {
            let day = calendar.startOfDay(for: record.startedAt)
            let (prevSecs, prevSes) = dailyMap[day] ?? (0, 0)
            dailyMap[day] = (prevSecs + Int(record.actualDuration), prevSes + 1)
        }

        var dailyDistribution: [ReportPayload.DailyDistributionItem] = []
        for dayOffset in 0..<period.days {
            let date = calendar.date(byAdding: .day, value: -(period.days - 1 - dayOffset), to: today) ?? today
            let (secs, ses) = dailyMap[date] ?? (0, 0)
            dailyDistribution.append(ReportPayload.DailyDistributionItem(
                day: dayFormatter.string(from: date),
                focusMinutes: secs / 60,
                sessions: ses
            ))
        }

        return ReportPayload(
            period: period.rawValue,
            periodStart: dateFormatter.string(from: periodStart),
            periodEnd: dateFormatter.string(from: periodEnd),
            summary: summary,
            trends: trends,
            patterns: patterns,
            taskBreakdown: taskBreakdown,
            dailyDistribution: dailyDistribution
        )
    }

    /// Encode payload to JSON string (for debugging/rawPayload storage).
    func encodePayload(_ payload: ReportPayload) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(payload),
              let json = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return json
    }
}
