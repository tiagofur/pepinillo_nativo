// TemplateReportGenerator.swift
// Pepinillo — Deep Work Companion for Apple
//
// Generates structured productivity reports from session data
// using template-based logic, replacing the backend AI dependency.

import Foundation

struct TemplateReportGenerator: Sendable {

    // MARK: - Generate

    func generate(from payload: ReportPayload) -> AIReportResponse {
        let title = buildTitle(from: payload)
        let highlights = buildHighlights(from: payload)
        let insights = buildInsights(from: payload)
        let recommendations = buildRecommendations(from: payload)

        return AIReportResponse(
            title: title,
            highlights: highlights,
            insights: insights,
            recommendations: recommendations
        )
    }

    // MARK: - Title

    private func buildTitle(from payload: ReportPayload) -> String {
        let period = payload.period.capitalized

        if payload.summary.focusQualityScore >= 80 {
            return String(localized: "A Strong \(period) of Focus")
        } else if payload.trends.completionRateDelta > 0.1 {
            return String(localized: "Building Momentum")
        } else if payload.trends.focusMinutesDelta > 0 {
            return String(localized: "Growing Your Focus Practice")
        } else {
            return String(localized: "Your \(period) in Review")
        }
    }

    // MARK: - Highlights

    private func buildHighlights(from payload: ReportPayload) -> [String] {
        let totalMinutes = payload.summary.totalFocusMinutes
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        let sessions = payload.summary.sessions

        let focusHighlight = String(
            localized: "You focused for \(hours)h \(minutes)m across \(sessions) sessions"
        )

        let ratePercent = Int(payload.summary.completionRate * 100)
        let completionHighlight: String
        let prevRate = payload.summary.completionRate - payload.trends.completionRateDelta
        let prevPercent = Int(prevRate * 100)
        if payload.trends.completionRateDelta > 0 {
            completionHighlight = String(
                localized: "Completion rate: \(ratePercent)% — up from \(prevPercent)%"
            )
        } else if payload.trends.completionRateDelta < 0 {
            completionHighlight = String(
                localized: "Completion rate: \(ratePercent)% — down from \(prevPercent)%"
            )
        } else {
            completionHighlight = String(
                localized: "Completion rate: \(ratePercent)%"
            )
        }

        let bestDay = payload.patterns.bestDay
        let bestDayHighlight = String(
            localized: "\(bestDay) was your most productive day"
        )

        return [focusHighlight, completionHighlight, bestDayHighlight]
    }

    // MARK: - Insights

    private func buildInsights(from payload: ReportPayload) -> [ReportInsight] {
        var insights: [ReportInsight] = []

        // Achievement insight
        if payload.summary.focusQualityScore >= 75 {
            let score = payload.summary.focusQualityScore
            insights.append(ReportInsight(
                category: "achievement",
                text: String(localized: "Your focus quality score of \(score) shows strong discipline")
            ))
        }

        // Pattern insight (always)
        let peakHours = payload.patterns.peakHours
        let dominantMode = payload.patterns.dominantMode
        insights.append(ReportInsight(
            category: "pattern",
            text: String(localized: "Your peak focus window is \(peakHours). \(dominantMode) is your preferred technique")
        ))

        // Improvement: high interruptions
        let sessions = payload.summary.sessions
        if sessions > 0 {
            let avgInterruptions = Double(payload.summary.interruptions) / Double(sessions)
            if avgInterruptions > 2 {
                let avg = String(format: "%.1f", avgInterruptions)
                insights.append(ReportInsight(
                    category: "improvement",
                    text: String(localized: "You averaged \(avg) interruptions per session. Consider using Do Not Disturb during focus blocks")
                ))
            }
        }

        // Improvement: declining completion rate
        if payload.trends.completionRateDelta < -0.05 {
            let period = payload.period
            insights.append(ReportInsight(
                category: "improvement",
                text: String(localized: "Your completion rate dropped this \(period). Try shorter sessions to rebuild consistency")
            ))
        }

        return insights
    }

    // MARK: - Recommendations

    private func buildRecommendations(from payload: ReportPayload) -> [String] {
        var recommendations: [String] = []

        // Peak hours recommendation
        let peakHours = payload.patterns.peakHours
        if !peakHours.isEmpty {
            recommendations.append(String(
                localized: "Schedule your hardest tasks during your \(peakHours) peak window"
            ))
        }

        // High interruptions recommendation
        let sessions = payload.summary.sessions
        if sessions > 0 {
            let avgInterruptions = Double(payload.summary.interruptions) / Double(sessions)
            if avgInterruptions > 2 {
                recommendations.append(String(
                    localized: "Try enabling Do Not Disturb or using shorter 15-minute sessions"
                ))
            }
        }

        // Task breakdown recommendation
        if let topTask = payload.taskBreakdown.first {
            let taskName = topTask.title
            let minutes = topTask.focusMinutes
            recommendations.append(String(
                localized: "Your top task '\(taskName)' consumed \(minutes)m — consider breaking it into subtasks"
            ))
        }

        // Declining trends recommendation
        if payload.trends.sessionsDelta < 0 {
            let prevSessions = payload.summary.sessions - payload.trends.sessionsDelta
            let period = payload.period
            recommendations.append(String(
                localized: "Aim for at least \(prevSessions) sessions next \(period) to match your previous pace"
            ))
        }

        return recommendations
    }
}
