// AIReportView.swift
// Pepinillo — Deep Work Companion for Apple
//
// SwiftUI view for AI-generated productivity reports.
// Presented as a sheet from AnalyticsView.
// Shows report title, highlights, categorized insights, and recommendations.

import SwiftUI
import ComposableArchitecture

struct AIReportView: View {
    @Bindable var store: StoreOf<AIReportFeature>
    @Environment(\.appTheme) private var theme
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                if store.isGenerating {
                    generatingView
                } else if let error = store.error {
                    errorView(error)
                } else if let report = store.report {
                    reportContent(report)
                } else {
                    // Transient state: onAppear will dispatch generateTapped immediately
                    generatingView
                }
            }
            .navigationTitle(store.period.displayName + " " + String(localized: "AI Report"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "Done")) { dismiss() }
                }
            }
            .onAppear { store.send(.onAppear) }
        }
    }

    // MARK: - Generating State

    private var generatingView: some View {
        VStack(spacing: 16) {
            Spacer()
                .frame(height: 60)

            ProgressView()
                .scaleEffect(1.5)

            Text(String(localized: "Generating your report..."))
                .font(.headline)
                .foregroundStyle(.secondary)

            Text(String(localized: "Analyzing your focus patterns and productivity data"))
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()
        }
    }

    // MARK: - Error State

    private func errorView(_ error: String) -> some View {
        VStack(spacing: 16) {
            Spacer()
                .frame(height: 60)

            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundStyle(.orange)

            Text(String(localized: "Report Generation Failed"))
                .font(.headline)

            Text(error)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button {
                store.send(.generateTapped)
            } label: {
                Label(String(localized: "Try Again"), systemImage: "arrow.clockwise")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 32)

            Spacer()
        }
    }

    // MARK: - Report Content

    private func reportContent(_ report: ProductivityReportDTO) -> some View {
        VStack(spacing: 20) {
            // Title
            Text(report.title)
                .font(.title2)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)

            // Generated date
            Text(String(localized: "Generated \(report.generatedAt, format: .dateTime.month().day().hour().minute())"))
                .font(.caption)
                .foregroundStyle(.tertiary)

            // Highlights
            if !report.highlights.isEmpty {
                highlightsSection(report.highlights)
            }

            // Insights by category
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
                    title: String(localized: "Patterns"),
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

            // Regenerate button
            Button {
                store.send(.generateTapped)
            } label: {
                Label(String(localized: "Regenerate Report"), systemImage: "arrow.clockwise")
                    .font(.subheadline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.bordered)
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 16)
        .padding(.bottom, 32)
    }

    // MARK: - Highlights

    private func highlightsSection(_ highlights: [String]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(String(localized: "Highlights"), systemImage: "sparkles")
                .font(.headline)

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
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .pepinilloGlass(cornerRadius: GlassCornerRadius.card)
        .padding(.horizontal, 16)
    }

    // MARK: - Insights Section

    private func insightsSection(title: String, icon: String, color: Color, insights: [ReportInsight]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon)
                .font(.headline)
                .foregroundStyle(color)

            ForEach(insights) { insight in
                Text(insight.text)
                    .font(.subheadline)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(color.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .pepinilloGlass(cornerRadius: GlassCornerRadius.card)
        .padding(.horizontal, 16)
    }

    // MARK: - Recommendations

    private func recommendationsSection(_ recommendations: [String]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(String(localized: "Recommendations"), systemImage: "lightbulb.fill")
                .font(.headline)
                .foregroundStyle(.orange)

            ForEach(Array(recommendations.enumerated()), id: \.offset) { index, recommendation in
                HStack(alignment: .top, spacing: 10) {
                    Text("\(index + 1).")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundStyle(.orange)
                        .frame(width: 20, alignment: .leading)
                    Text(recommendation)
                        .font(.subheadline)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .pepinilloGlass(cornerRadius: GlassCornerRadius.card)
        .padding(.horizontal, 16)
    }

    // MARK: - Helpers

    private func groupedInsights(_ insights: [ReportInsight]) -> [String: [ReportInsight]] {
        Dictionary(grouping: insights, by: \.category)
    }
}
