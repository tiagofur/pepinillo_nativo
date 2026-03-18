// ModeIntelligenceService.swift
// Pepinillo — Deep Work Companion for Apple
//
// Analyzes historical FocusSessionRecord data per task to suggest
// the best focus mode. Requires at least 2 weeks of data before
// making confident suggestions.
//
// Usage: Called in FocusFeature when a task is linked to a session.
// If confidence > 70%, a suggestion banner is shown.

import Foundation

struct ModeSuggestion: Equatable, Sendable {
    let suggestedMode: FocusMode
    let confidence: Double           // 0.0–1.0
    let reason: String               // Human-readable explanation
}

struct ModeIntelligenceService: Sendable {

    /// Analyze session history for a specific task and suggest the best mode.
    /// Returns nil if insufficient data or no clear winner.
    func suggestMode(
        forTaskID taskID: UUID,
        sessions: [SessionRecordDTO],
        minimumSessions: Int = 3
    ) -> ModeSuggestion? {
        // Filter to completed sessions for this task
        let taskSessions = sessions.filter { $0.taskID == taskID && $0.wasCompleted }
        guard taskSessions.count >= minimumSessions else { return nil }

        // Group by mode and calculate stats
        var modeStats: [FocusMode: ModeStats] = [:]
        for record in taskSessions {
            guard let mode = FocusMode(rawValue: record.mode) else { continue }
            var stats = modeStats[mode] ?? ModeStats()
            stats.totalSessions += 1
            stats.totalDuration += record.actualDuration
            stats.completedSessions += record.wasCompleted ? 1 : 0
            modeStats[mode] = stats
        }

        guard !modeStats.isEmpty else { return nil }

        // Score each mode: completionRate * 0.6 + avgDurationNormalized * 0.4
        let maxAvgDuration = modeStats.values.map { $0.averageDuration }.max() ?? 1
        var scores: [(FocusMode, Double)] = []

        for (mode, stats) in modeStats {
            let completionRate = stats.completionRate
            let durationScore = maxAvgDuration > 0
                ? stats.averageDuration / maxAvgDuration
                : 0
            let score = completionRate * 0.6 + durationScore * 0.4
            scores.append((mode, score))
        }

        scores.sort { $0.1 > $1.1 }
        guard let best = scores.first else { return nil }

        // Need at least 70% confidence and a clear margin over second best
        let confidence = best.1
        guard confidence >= 0.7 else { return nil }

        if scores.count > 1 {
            let margin = best.1 - scores[1].1
            guard margin >= 0.1 else { return nil }  // Need 10% margin
        }

        let stats = modeStats[best.0]!
        let avgMinutes = Int(stats.averageDuration / 60)
        let reason = String(
            localized: "You complete \(Int(stats.completionRate * 100))% of sessions in \(best.0.displayName) (avg \(avgMinutes)m)"
        )

        return ModeSuggestion(
            suggestedMode: best.0,
            confidence: confidence,
            reason: reason
        )
    }

    /// Broader analysis: suggest mode based on energy level patterns across all tasks.
    func suggestModeForEnergyLevel(
        _ energyLevel: EnergyLevel,
        sessions: [SessionRecordDTO],
        taskIDs: Set<UUID>,
        minimumSessions: Int = 5
    ) -> ModeSuggestion? {
        // Filter to sessions for tasks with this energy level
        let relevantSessions = sessions.filter {
            guard let taskID = $0.taskID else { return false }
            return taskIDs.contains(taskID) && $0.wasCompleted
        }

        guard relevantSessions.count >= minimumSessions else { return nil }

        var modeStats: [FocusMode: ModeStats] = [:]
        for record in relevantSessions {
            guard let mode = FocusMode(rawValue: record.mode) else { continue }
            var stats = modeStats[mode] ?? ModeStats()
            stats.totalSessions += 1
            stats.totalDuration += record.actualDuration
            stats.completedSessions += record.wasCompleted ? 1 : 0
            modeStats[mode] = stats
        }

        guard let best = modeStats.max(by: { $0.value.completionRate < $1.value.completionRate }) else {
            return nil
        }

        let confidence = best.value.completionRate
        guard confidence >= 0.7 else { return nil }

        let reason = String(
            localized: "\(energyLevel.displayName) tasks go best with \(best.key.displayName)"
        )

        return ModeSuggestion(
            suggestedMode: best.key,
            confidence: confidence,
            reason: reason
        )
    }
}

// MARK: - Private

private struct ModeStats {
    var totalSessions: Int = 0
    var completedSessions: Int = 0
    var totalDuration: TimeInterval = 0

    var completionRate: Double {
        guard totalSessions > 0 else { return 0 }
        return Double(completedSessions) / Double(totalSessions)
    }

    var averageDuration: TimeInterval {
        guard totalSessions > 0 else { return 0 }
        return totalDuration / Double(totalSessions)
    }
}
