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

    /// Load a cached report from the Caches directory (issue #86).
    /// Previously cached in UserDefaults, which is loaded into memory at launch
    /// and never purged — large AI report payloads (including the full `rawPayload`
    /// JSON) inflated cold-start memory and polluted the defaults plist.
    /// The cache key is scoped to the current user ID so that after an account switch,
    /// user B never sees user A's cached report.
    private func loadCachedReport(period: ReportPeriod, periodStart: Date) async throws -> ProductivityReportDTO? {
        let userScope = (try? await persistence.fetchCachedUser())?.id ?? "anonymous"
        guard let url = Self.cacheURL(for: userScope, period: period.rawValue),
              FileManager.default.fileExists(atPath: url.path) else { return nil }
        guard let data = try? Data(contentsOf: url) else { return nil }

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

    /// Cache a report to the Caches directory.
    /// Key is user-scoped to prevent cross-user cache leaks on account switch.
    private func cacheReport(_ dto: ProductivityReportDTO) async throws {
        let userScope = (try? await persistence.fetchCachedUser())?.id ?? "anonymous"
        guard let url = Self.cacheURL(for: userScope, period: dto.period) else { return }

        struct CachedReport: Codable {
            let dto: CodableReportDTO
            let cachedAt: Date
        }

        let cached = CachedReport(dto: CodableReportDTO(from: dto), cachedAt: .now)
        if let data = try? JSONEncoder().encode(cached) {
            // Ensure the directory exists (it may not on first run).
            let dir = url.deletingLastPathComponent()
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            try? data.write(to: url, options: .atomic)
        }
    }

    /// Remove all cached AI reports from the Caches directory.
    /// Call this on sign-out and account deletion so the next user starts fresh.
    static func clearAllCachedReports() {
        // Issue #86: previously used defaults.dictionaryRepresentation() which
        // loads ALL system defaults into memory just to filter a prefix. Now we
        // enumerate the cache directory directly — no memory overhead.
        guard let cacheDir = cacheDirectory() else { return }
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(at: cacheDir, includingPropertiesForKeys: nil) else { return }
        for fileURL in entries where fileURL.lastPathComponent.hasPrefix("cachedReport_") {
            try? fm.removeItem(at: fileURL)
        }
    }

    // MARK: - Cache directory helpers

    /// The Caches subdirectory for AI reports.
    private static func cacheDirectory() -> URL? {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent("com.pepinillo.reports", isDirectory: true)
    }

    /// File URL for a specific user+period cache entry.
    private static func cacheURL(for userScope: String, period: String) -> URL? {
        cacheDirectory()?.appendingPathComponent("cachedReport_\(userScope)_\(period).json")
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
