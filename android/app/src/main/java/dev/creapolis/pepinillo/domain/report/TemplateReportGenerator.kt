package dev.creapolis.pepinillo.domain.report

import android.content.Context
import dagger.hilt.android.qualifiers.ApplicationContext
import dev.creapolis.pepinillo.R
import dev.creapolis.pepinillo.core.network.AIReportResponse
import dev.creapolis.pepinillo.core.network.ReportInsight
import java.util.Locale
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class TemplateReportGenerator @Inject constructor(
    @ApplicationContext private val context: Context,
) {

    fun generate(payload: ReportPayload): AIReportResponse {
        val title = buildTitle(payload)
        val highlights = buildHighlights(payload)
        val insights = buildInsights(payload)
        val recommendations = buildRecommendations(payload)

        return AIReportResponse(
            title = title,
            highlights = highlights,
            insights = insights,
            recommendations = recommendations,
        )
    }

    // -- Title --

    private fun buildTitle(payload: ReportPayload): String {
        val periodLabel = periodLabel(payload.period)
        val qualityScore = computeFocusQualityScore(payload)
        val completionRateDelta = computeCompletionRateDelta(payload)

        return when {
            qualityScore >= 80 ->
                context.getString(R.string.report_title_strong, periodLabel)
            completionRateDelta > 0.1 ->
                context.getString(R.string.report_title_momentum)
            payload.trends.minutesChange > 0 ->
                context.getString(R.string.report_title_growing)
            else ->
                context.getString(R.string.report_title_review, periodLabel)
        }
    }

    // -- Highlights --

    private fun buildHighlights(payload: ReportPayload): List<String> {
        val totalMinutes = payload.summary.totalMinutes
        val hours = totalMinutes / 60
        val minutes = totalMinutes % 60
        val sessions = payload.summary.totalSessions

        val focusHighlight = context.getString(
            R.string.report_highlight_focus, hours, minutes, sessions,
        )

        val completionRate = computeCompletionRate(payload)
        val completionRateDelta = computeCompletionRateDelta(payload)
        val ratePercent = (completionRate * 100).toInt()
        val prevPercent = ((completionRate - completionRateDelta) * 100).toInt()

        val completionHighlight = when {
            completionRateDelta > 0 ->
                context.getString(R.string.report_highlight_completion_up, ratePercent, prevPercent)
            completionRateDelta < 0 ->
                context.getString(R.string.report_highlight_completion_down, ratePercent, prevPercent)
            else ->
                context.getString(R.string.report_highlight_completion, ratePercent)
        }

        val bestDay = payload.patterns.bestDayOfWeek
        val bestDayHighlight = context.getString(R.string.report_highlight_best_day, bestDay)

        return listOf(focusHighlight, completionHighlight, bestDayHighlight)
    }

    // -- Insights --

    private fun buildInsights(payload: ReportPayload): List<ReportInsight> {
        val insights = mutableListOf<ReportInsight>()

        // Achievement insight
        val qualityScore = computeFocusQualityScore(payload)
        if (qualityScore >= 75) {
            insights += ReportInsight(
                category = "achievement",
                text = context.getString(R.string.report_insight_quality, qualityScore),
            )
        }

        // Pattern insight (always)
        val peakHours = payload.patterns.peakHourRange
        val dominantMode = payload.patterns.dominantMode ?: "Pomodoro"
        insights += ReportInsight(
            category = "pattern",
            text = context.getString(R.string.report_insight_pattern, peakHours, dominantMode),
        )

        // Improvement: high interruptions
        val sessions = payload.summary.totalSessions
        if (sessions > 0) {
            val avgInterruptions = payload.summary.totalInterruptions.toDouble() / sessions
            if (avgInterruptions > 2) {
                val avg = String.format(Locale.getDefault(), "%.1f", avgInterruptions)
                insights += ReportInsight(
                    category = "improvement",
                    text = context.getString(R.string.report_insight_interruptions, avg),
                )
            }
        }

        // Improvement: declining completion rate
        val completionRateDelta = computeCompletionRateDelta(payload)
        if (completionRateDelta < -0.05) {
            val periodLabel = periodLabel(payload.period)
            insights += ReportInsight(
                category = "improvement",
                text = context.getString(R.string.report_insight_completion_drop, periodLabel),
            )
        }

        return insights
    }

    // -- Recommendations --

    private fun buildRecommendations(payload: ReportPayload): List<String> {
        val recommendations = mutableListOf<String>()

        // Peak hours recommendation
        val peakHours = payload.patterns.peakHourRange
        if (peakHours.isNotEmpty()) {
            recommendations += context.getString(R.string.report_rec_peak_hours, peakHours)
        }

        // High interruptions recommendation
        val sessions = payload.summary.totalSessions
        if (sessions > 0) {
            val avgInterruptions = payload.summary.totalInterruptions.toDouble() / sessions
            if (avgInterruptions > 2) {
                recommendations += context.getString(R.string.report_rec_dnd)
            }
        }

        // Top task recommendation
        val topTask = payload.taskBreakdown.firstOrNull()
        if (topTask != null) {
            recommendations += context.getString(R.string.report_rec_top_task, topTask.totalMinutes)
        }

        // Declining trends recommendation
        if (payload.trends.sessionsChange < 0) {
            val prevSessions = payload.summary.totalSessions - payload.trends.sessionsChange
            val periodLabel = periodLabel(payload.period)
            recommendations += context.getString(R.string.report_rec_match_pace, prevSessions, periodLabel)
        }

        return recommendations
    }

    // -- Helpers --

    private fun computeFocusQualityScore(payload: ReportPayload): Int {
        val sessions = payload.summary.totalSessions
        if (sessions == 0) return 0
        val completionRate = computeCompletionRate(payload)
        val avgInterruptions = payload.summary.totalInterruptions.toDouble() / sessions
        // Score: weighted combination of completion rate and low interruptions
        val interruptionPenalty = (avgInterruptions * 10).coerceAtMost(40.0)
        return ((completionRate * 100) - interruptionPenalty).toInt().coerceIn(0, 100)
    }

    private fun computeCompletionRate(payload: ReportPayload): Double {
        val total = payload.summary.totalSessions
        if (total == 0) return 0.0
        return payload.summary.completedSessions.toDouble() / total
    }

    private fun computeCompletionRateDelta(payload: ReportPayload): Double {
        // ReportTrends does not track previousCompletedSessions, so we cannot
        // compute an exact completion-rate delta. Return 0 until the payload is
        // extended with that field (tracked for Gemini Nano phase).
        return 0.0
    }

    private fun periodLabel(period: String): String {
        return when (period) {
            "week" -> context.getString(R.string.report_period_week)
            "month" -> context.getString(R.string.report_period_month)
            else -> period.replaceFirstChar { it.titlecase(Locale.getDefault()) }
        }
    }
}
