// ProductivityReport.swift
// Pepinillo — Deep Work Companion for Apple
//
// SwiftData model for cached AI-generated productivity reports.
// One record per generated report (weekly or monthly).

import Foundation
import SwiftData

@Model
public final class ProductivityReport {
    public var id: UUID
    public var period: String                // "week" or "month"
    public var periodStart: Date
    public var periodEnd: Date
    public var generatedAt: Date
    public var title: String
    public var highlightsJSON: String         // JSON-encoded [String]
    public var insightsJSON: String           // JSON-encoded [ReportInsight]
    public var recommendationsJSON: String    // JSON-encoded [String]
    public var rawPayload: String             // The JSON sent to AI for debugging

    public init(
        id: UUID = UUID(),
        period: String,
        periodStart: Date,
        periodEnd: Date,
        generatedAt: Date = .now,
        title: String,
        highlights: [String],
        insights: [ReportInsight],
        recommendations: [String],
        rawPayload: String = ""
    ) {
        self.id = id
        self.period = period
        self.periodStart = periodStart
        self.periodEnd = periodEnd
        self.generatedAt = generatedAt
        self.title = title
        self.highlightsJSON = (try? String(data: JSONEncoder().encode(highlights), encoding: .utf8)) ?? "[]"
        self.insightsJSON = (try? String(data: JSONEncoder().encode(insights), encoding: .utf8)) ?? "[]"
        self.recommendationsJSON = (try? String(data: JSONEncoder().encode(recommendations), encoding: .utf8)) ?? "[]"
        self.rawPayload = rawPayload
    }

    // MARK: - Decoded accessors

    public var highlights: [String] {
        guard let data = highlightsJSON.data(using: .utf8) else { return [] }
        return (try? JSONDecoder().decode([String].self, from: data)) ?? []
    }

    public var insights: [ReportInsight] {
        guard let data = insightsJSON.data(using: .utf8) else { return [] }
        return (try? JSONDecoder().decode([ReportInsight].self, from: data)) ?? []
    }

    public var recommendations: [String] {
        guard let data = recommendationsJSON.data(using: .utf8) else { return [] }
        return (try? JSONDecoder().decode([String].self, from: data)) ?? []
    }
}

// MARK: - Supporting Types

public struct ReportInsight: Codable, Sendable, Equatable, Identifiable {
    public var id: String { "\(category)-\(text.prefix(20))" }
    public let category: String  // "pattern", "improvement", "achievement"
    public let text: String

    public init(category: String, text: String) {
        self.category = category
        self.text = text
    }
}

public struct AIReportResponse: Codable, Sendable, Equatable {
    public let title: String
    public let highlights: [String]
    public let insights: [ReportInsight]
    public let recommendations: [String]

    public init(title: String, highlights: [String], insights: [ReportInsight], recommendations: [String]) {
        self.title = title
        self.highlights = highlights
        self.insights = insights
        self.recommendations = recommendations
    }
}

/// Sendable DTO for transferring ProductivityReport data across concurrency boundaries.
public struct ProductivityReportDTO: Sendable, Equatable {
    public let id: UUID
    public let period: String
    public let periodStart: Date
    public let periodEnd: Date
    public let generatedAt: Date
    public let title: String
    public let highlights: [String]
    public let insights: [ReportInsight]
    public let recommendations: [String]
    public let rawPayload: String

    public init(from report: ProductivityReport) {
        self.id = report.id
        self.period = report.period
        self.periodStart = report.periodStart
        self.periodEnd = report.periodEnd
        self.generatedAt = report.generatedAt
        self.title = report.title
        self.highlights = report.highlights
        self.insights = report.insights
        self.recommendations = report.recommendations
        self.rawPayload = report.rawPayload
    }

    public init(
        id: UUID = UUID(),
        period: String,
        periodStart: Date,
        periodEnd: Date,
        generatedAt: Date = .now,
        title: String,
        highlights: [String],
        insights: [ReportInsight],
        recommendations: [String],
        rawPayload: String = ""
    ) {
        self.id = id
        self.period = period
        self.periodStart = periodStart
        self.periodEnd = periodEnd
        self.generatedAt = generatedAt
        self.title = title
        self.highlights = highlights
        self.insights = insights
        self.recommendations = recommendations
        self.rawPayload = rawPayload
    }
}
