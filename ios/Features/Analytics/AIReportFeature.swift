// AIReportFeature.swift
// Pepinillo — Deep Work Companion for Apple
//
// TCA Reducer for AI-generated productivity reports.
// Builds a data payload from session history, sends it to the AI backend,
// and caches the resulting report in SwiftData.

import Foundation
import ComposableArchitecture

@Reducer
struct AIReportFeature {

    @ObservableState
    struct State: Equatable {
        var period: ReportPeriod
        var report: ProductivityReportDTO?
        var isGenerating: Bool = false
        var error: String?

        init(period: ReportPeriod = .week) {
            self.period = period
        }
    }

    enum Action: Equatable {
        case onAppear
        case generateTapped
        case reportGenerated(ProductivityReportDTO)
        case reportFailed(String)
        case cachedReportLoaded(ProductivityReportDTO?)
        case dismiss
    }

    @Dependency(\.persistenceClient) var persistence
    @Dependency(\.aiReportClient) var aiReportClient

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {

            case .onAppear:
                let period = state.period
                return .run { send in
                    // Check for cached report for this period
                    let calendar = Calendar.current
                    let today = calendar.startOfDay(for: .now)
                    let periodStart = calendar.date(byAdding: .day, value: -(period.days - 1), to: today) ?? today

                    // Try to find a cached report via sessions fetch to check if one exists
                    // We'll store/retrieve reports via a separate mechanism
                    let cached = try? await loadCachedReport(period: period, periodStart: periodStart)
                    await send(.cachedReportLoaded(cached))
                }

            case .cachedReportLoaded(let cached):
                if let cached {
                    state.report = cached
                    state.isGenerating = false
                } else {
                    // No cached report, auto-generate
                    return .send(.generateTapped)
                }
                return .none

            case .generateTapped:
                state.isGenerating = true
                state.error = nil
                let period = state.period
                return .run { send in
                    do {
                        let payload = try await buildPayload(for: period)
                        let response = try await aiReportClient.generateReport(payload)

                        let calendar = Calendar.current
                        let today = calendar.startOfDay(for: .now)
                        let periodStart = calendar.date(byAdding: .day, value: -(period.days - 1), to: today) ?? today

                        let builder = ReportDataBuilder()
                        let rawPayload = builder.encodePayload(payload)

                        let reportDTO = ProductivityReportDTO(
                            period: period.rawValue,
                            periodStart: periodStart,
                            periodEnd: today,
                            generatedAt: .now,
                            title: response.title,
                            highlights: response.highlights,
                            insights: response.insights,
                            recommendations: response.recommendations,
                            rawPayload: rawPayload
                        )

                        // Cache the report
                        try? await cacheReport(reportDTO)

                        await send(.reportGenerated(reportDTO))
                    } catch {
                        await send(.reportFailed(error.localizedDescription))
                    }
                }

            case .reportGenerated(let report):
                state.isGenerating = false
                state.report = report
                state.error = nil
                return .none

            case .reportFailed(let error):
                state.isGenerating = false
                state.error = error
                return .none

            case .dismiss:
                return .none
            }
        }
    }

    // MARK: - Private Helpers

    private func buildPayload(for period: ReportPeriod) async throws -> ReportPayload {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let endOfToday = calendar.date(byAdding: .day, value: 1, to: today)!
        let currentStart = calendar.date(byAdding: .day, value: -(period.days - 1), to: today)!
        let previousStart = calendar.date(byAdding: .day, value: -(period.days * 2 - 1), to: today)!

        async let currentFetch = persistence.fetchSessions(currentStart, endOfToday)
        async let previousFetch = persistence.fetchSessions(previousStart, currentStart)
        async let tasksFetch = persistence.fetchTasks()

        let (current, previous, tasks) = try await (currentFetch, previousFetch, tasksFetch)

        let builder = ReportDataBuilder()
        return builder.buildPayload(
            period: period,
            currentSessions: current,
            previousSessions: previous,
            tasks: tasks,
            calendar: calendar
        )
    }

    /// Load a cached report from UserDefaults (lightweight cache for the current period).
    private func loadCachedReport(period: ReportPeriod, periodStart: Date) async throws -> ProductivityReportDTO? {
        let key = "cachedReport_\(period.rawValue)"
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }

        struct CachedReport: Codable {
            let dto: CodableReportDTO
            let cachedAt: Date
        }

        guard let cached = try? JSONDecoder().decode(CachedReport.self, from: data) else { return nil }

        // Reports are valid for 1 hour
        let age = Date.now.timeIntervalSince(cached.cachedAt)
        guard age < 3600 else { return nil }

        return cached.dto.toDTO()
    }

    /// Cache a report to UserDefaults.
    private func cacheReport(_ dto: ProductivityReportDTO) async throws {
        let key = "cachedReport_\(dto.period)"

        struct CachedReport: Codable {
            let dto: CodableReportDTO
            let cachedAt: Date
        }

        let cached = CachedReport(dto: CodableReportDTO(from: dto), cachedAt: .now)
        if let data = try? JSONEncoder().encode(cached) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}

// MARK: - Codable wrapper for UserDefaults caching

private struct CodableReportDTO: Codable {
    let id: UUID
    let period: String
    let periodStart: Date
    let periodEnd: Date
    let generatedAt: Date
    let title: String
    let highlights: [String]
    let insights: [ReportInsight]
    let recommendations: [String]
    let rawPayload: String

    init(from dto: ProductivityReportDTO) {
        self.id = dto.id
        self.period = dto.period
        self.periodStart = dto.periodStart
        self.periodEnd = dto.periodEnd
        self.generatedAt = dto.generatedAt
        self.title = dto.title
        self.highlights = dto.highlights
        self.insights = dto.insights
        self.recommendations = dto.recommendations
        self.rawPayload = dto.rawPayload
    }

    func toDTO() -> ProductivityReportDTO {
        ProductivityReportDTO(
            id: id,
            period: period,
            periodStart: periodStart,
            periodEnd: periodEnd,
            generatedAt: generatedAt,
            title: title,
            highlights: highlights,
            insights: insights,
            recommendations: recommendations,
            rawPayload: rawPayload
        )
    }
}
