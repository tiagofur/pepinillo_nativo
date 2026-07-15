// AIInsightsContent.swift
// Pepinillo — Deep Work Companion for Apple
//
// Shared AI Insights content used inside Weekly and Monthly Review tabs.
// Generates a productivity report with score, highlights, patterns,
// and actionable recommendations.
// Uses Apple Foundation Models (iOS 26+) with template fallback.

import SwiftUI
import ComposableArchitecture

struct AIInsightsContent: View {
    let period: ReportPeriod
    let analyticsStore: StoreOf<AnalyticsFeature>

    @Environment(\.appTheme) private var theme
    @State private var reportStore: StoreOf<AIReportFeature>?

    var body: some View {
        VStack(spacing: SpacingTokens.md) {
            if let reportStore {
                AIReportContentView(
                    store: reportStore,
                    period: period,
                    theme: theme
                )
            } else {
                loadingState
            }
        }
        .onAppear {
            if reportStore == nil {
                reportStore = Store(initialState: AIReportFeature.State(period: period)) {
                    AIReportFeature()
                }
            }
        }
    }

    private var loadingState: some View {
        VStack(spacing: SpacingTokens.md) {
            Spacer()
                .frame(height: 80)
            ProgressView()
                .scaleEffect(1.5)
            Text(String(localized: "Preparing AI Insights..."))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }
}

// MARK: - Report Content (richer version with Productivity Score)

struct AIReportContentView: View {
    @Bindable var store: StoreOf<AIReportFeature>
    let period: ReportPeriod
    let theme: AppTheme

    var body: some View {
        if store.isGenerating {
            generatingView
        } else if let error = store.error {
            errorView(error)
        } else if let report = store.report {
            reportContent(report)
        } else {
            // No report yet and not generating — trigger load
            loadingBeforeGenerate
        }
    }

    private var loadingBeforeGenerate: some View {
        VStack(spacing: SpacingTokens.md) {
            Spacer()
                .frame(height: 80)
            ProgressView()
                .scaleEffect(1.5)
            Text(String(localized: "Analyzing your patterns..."))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .onAppear { store.send(.onAppear) }
    }

    // MARK: - Generating

    private var generatingView: some View {
        VStack(spacing: SpacingTokens.md) {
            Spacer()
                .frame(height: 80)

            ProgressView()
                .scaleEffect(1.5)

            Text(String(localized: "Analyzing your patterns..."))
                .font(.headline)
                .foregroundStyle(.secondary)

            Text(String(localized: "Apple Intelligence is reading your focus data"))
                .font(.caption)
                .foregroundStyle(.tertiary)

            Spacer()
        }
    }

    // MARK: - Error

    private func errorView(_ error: String) -> some View {
        VStack(spacing: SpacingTokens.md) {
            Spacer()
                .frame(height: 60)

            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundStyle(.orange)

            Text(String(localized: "Could not generate report"))
                .font(.headline)

            Text(error)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, SpacingTokens.xxl)

            Button {
                store.send(.generateTapped)
            } label: {
                Label(String(localized: "Try Again"), systemImage: "arrow.clockwise")
            }
            .buttonStyle(.borderedProminent)

            Spacer()
        }
    }

    // MARK: - Report Content

    private func reportContent(_ report: ProductivityReportDTO) -> some View {
        VStack(spacing: SpacingTokens.lg) {
            // Headline
            headlineSection(report)

            // Productivity Score
            productivityScoreCard(report)

            // Highlights
            if !report.highlights.isEmpty {
                highlightsSection(report.highlights)
            }

            // Insights grouped by category
            let grouped = groupedInsights(report.insights)

            if let achievements = grouped["achievement"], !achievements.isEmpty {
                insightsSection(
                    title: String(localized: "Achievements"),
                    icon: "trophy.fill",
                    color: .yellow,
                    insights: achievements
                )
            }

            if let patterns = grouped["pattern"], !patterns.isEmpty {
                insightsSection(
                    title: String(localized: "Patterns Detected"),
                    icon: "chart.line.uptrend.xyaxis",
                    color: .blue,
                    insights: patterns
                )
            }

            if let improvements = grouped["improvement"], !improvements.isEmpty {
                insightsSection(
                    title: String(localized: "Areas to Improve"),
                    icon: "arrow.up.circle.fill",
                    color: .green,
                    insights: improvements
                )
            }

            // Recommendations
            if !report.recommendations.isEmpty {
                recommendationsSection(report.recommendations)
            }

            // Regenerate
            Button {
                store.send(.generateTapped)
            } label: {
                Label(String(localized: "Regenerate Insights"), systemImage: "arrow.clockwise")
                    .font(.subheadline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.bordered)
            .padding(.horizontal, SpacingTokens.md)

            Text(String(localized: "Generated \(report.generatedAt, format: .dateTime.month().day().hour().minute())"))
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, SpacingTokens.sm)
        .padding(.bottom, SpacingTokens.xxl)
    }

    // MARK: - Headline

    private func headlineSection(_ report: ProductivityReportDTO) -> some View {
        VStack(spacing: SpacingTokens.sm) {
            Image(systemName: "sparkles")
                .font(.title2)
                .foregroundStyle(.teal)

            Text(report.title)
                .font(.title3.bold())
                .multilineTextAlignment(.center)
                .padding(.horizontal, SpacingTokens.xl)
        }
        .padding(.top, SpacingTokens.sm)
    }

    // MARK: - Productivity Score

    private func productivityScoreCard(_ report: ProductivityReportDTO) -> some View {
        let score = computeScore(from: report)
        let color = scoreColor(score)
        let label = scoreLabel(score)

        return VStack(spacing: SpacingTokens.base) {
            Text(String(localized: "Productivity Score"))
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)

            ZStack {
                Circle()
                    .stroke(Color(.tertiarySystemFill), lineWidth: 8)
                    .frame(width: 100, height: 100)

                Circle()
                    .trim(from: 0, to: CGFloat(score) / 100)
                    .stroke(color.gradient, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 100, height: 100)
                    .rotationEffect(.degrees(-90))

                Text("\(score)")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(color)
            }

            Text(label)
                .font(.caption.weight(.medium))
                .foregroundStyle(color)
        }
        .padding(SpacingTokens.lg)
        .frame(maxWidth: .infinity)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: GlassCornerRadius.control, style: .continuous))
        .padding(.horizontal, SpacingTokens.md)
    }

    // MARK: - Highlights

    private func highlightsSection(_ highlights: [String]) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.base) {
            Label(String(localized: "Highlights"), systemImage: "sparkles")
                .font(.subheadline.weight(.semibold))

            ForEach(Array(highlights.enumerated()), id: \.offset) { _, highlight in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "star.fill")
                        .font(.caption)
                        .foregroundStyle(theme.pomodoroColor)
                        .padding(.top, 3)
                    Text(highlight)
                        .font(.subheadline)
                }
            }
        }
        .padding(SpacingTokens.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .pepinilloGlass(cornerRadius: GlassCornerRadius.card)
        .padding(.horizontal, SpacingTokens.md)
    }

    // MARK: - Insights Section

    private func insightsSection(title: String, icon: String, color: Color, insights: [ReportInsight]) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.base) {
            Label(title, systemImage: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(color)

            ForEach(insights) { insight in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: iconForCategory(insight.category))
                        .font(.caption)
                        .foregroundStyle(color)
                        .padding(.top, 3)
                    Text(insight.text)
                        .font(.subheadline)
                }
                .padding(SpacingTokens.base)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(color.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: GlassCornerRadius.tile, style: .continuous))
            }
        }
        .padding(SpacingTokens.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .pepinilloGlass(cornerRadius: GlassCornerRadius.card)
        .padding(.horizontal, SpacingTokens.md)
    }

    // MARK: - Recommendations

    private func recommendationsSection(_ recommendations: [String]) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.base) {
            Label(String(localized: "Recommendations"), systemImage: "lightbulb.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.orange)

            ForEach(Array(recommendations.enumerated()), id: \.offset) { index, recommendation in
                HStack(alignment: .top, spacing: 10) {
                    Text("\(index + 1).")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.orange)
                        .frame(width: 20, alignment: .leading)
                    Text(recommendation)
                        .font(.subheadline)
                }
            }
        }
        .padding(SpacingTokens.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .pepinilloGlass(cornerRadius: GlassCornerRadius.card)
        .padding(.horizontal, SpacingTokens.md)
    }

    // MARK: - Score Helpers

    private func computeScore(from report: ProductivityReportDTO) -> Int {
        // Base score from number of highlights and insights
        let highlightScore = min(report.highlights.count * 10, 30)
        let achievementCount = report.insights.filter { $0.category == "achievement" }.count
        let patternCount = report.insights.filter { $0.category == "pattern" }.count
        let improvementCount = report.insights.filter { $0.category == "improvement" }.count
        let insightScore = min((achievementCount * 12 + patternCount * 8), 40)
        let recommendationBonus = min(report.recommendations.count * 3, 15)
        let improvementPenalty = min(improvementCount * 5, 20)

        let raw = 40 + highlightScore + insightScore + recommendationBonus - improvementPenalty
        return max(10, min(100, raw))
    }

    private func scoreColor(_ score: Int) -> Color {
        switch score {
        case 80...100: return .green
        case 60..<80:  return .teal
        case 40..<60:  return .orange
        default:       return .red
        }
    }

    private func scoreLabel(_ score: Int) -> String {
        switch score {
        case 90...100: return String(localized: "Outstanding")
        case 80..<90:  return String(localized: "Excellent")
        case 70..<80:  return String(localized: "Great")
        case 60..<70:  return String(localized: "Good")
        case 50..<60:  return String(localized: "Building")
        case 40..<50:  return String(localized: "Room to Grow")
        default:       return String(localized: "Getting Started")
        }
    }

    private func iconForCategory(_ category: String) -> String {
        switch category {
        case "achievement":  return "trophy.fill"
        case "pattern":      return "magnifyingglass"
        case "improvement":  return "arrow.up.circle.fill"
        default:             return "circle.fill"
        }
    }

    private func groupedInsights(_ insights: [ReportInsight]) -> [String: [ReportInsight]] {
        Dictionary(grouping: insights, by: \.category)
    }
}
