// AIReportClient.swift
// Pepinillo — Deep Work Companion for Apple
//
// TCA Dependency Client for productivity reports.
// Uses TemplateReportGenerator to produce reports locally
// without any backend API dependency.

import Foundation
import ComposableArchitecture

// MARK: - Client

@DependencyClient
public struct AIReportClient: Sendable {
    /// Generate an AI productivity report from the given payload.
    public var generateReport: @Sendable (ReportPayload) async throws -> AIReportResponse
}

// MARK: - DependencyKey

extension AIReportClient: DependencyKey {
    public static let liveValue = AIReportClient(
        generateReport: { payload in
            // Try Apple Foundation Models on-device AI first (iOS 26+)
            let onDevice = OnDeviceReportGenerator()
            if let result = await onDevice.generate(from: payload) {
                return result
            }
            // Fallback to template-based generation
            let generator = TemplateReportGenerator()
            return generator.generate(from: payload)
        }
    )

    public static let testValue = AIReportClient()

    /// Preview/mock implementation that returns sample data without network calls.
    public static let previewValue = AIReportClient(
        generateReport: { _ in
            // Simulate network delay
            try await Task.sleep(for: .seconds(1))
            return AIReportResponse(
                title: "Your Week in Focus",
                highlights: [
                    "You focused for 12h 30m across 24 sessions",
                    "Completion rate improved by 15% vs last week",
                    "Tuesday was your most productive day"
                ],
                insights: [
                    ReportInsight(category: "achievement", text: "You maintained a 5-day focus streak — your longest this month!"),
                    ReportInsight(category: "pattern", text: "Your peak productivity window is 9 AM - 11 AM. Schedule your hardest tasks here."),
                    ReportInsight(category: "improvement", text: "Sessions after 3 PM had 40% more interruptions. Consider shorter sessions in the afternoon.")
                ],
                recommendations: [
                    "Try scheduling your most challenging task during your 9-11 AM peak window",
                    "Consider 15-minute Pomodoros for afternoon sessions to maintain completion rate",
                    "Your Flowtime sessions are 30% longer than Pomodoro — use Flowtime for creative work"
                ]
            )
        }
    )
}

// MARK: - Errors

public enum AIReportError: LocalizedError, Equatable, Sendable {
    case invalidURL
    case invalidResponse
    case serverError(statusCode: Int, body: String)
    case decodingError(String)

    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return String(localized: "Invalid server URL")
        case .invalidResponse:
            return String(localized: "Invalid server response")
        case .serverError(let code, _):
            return String(localized: "Server error (\(code))")
        case .decodingError(let msg):
            return String(localized: "Failed to parse report: \(msg)")
        }
    }
}

// MARK: - DependencyValues

extension DependencyValues {
    public var aiReportClient: AIReportClient {
        get { self[AIReportClient.self] }
        set { self[AIReportClient.self] = newValue }
    }
}
