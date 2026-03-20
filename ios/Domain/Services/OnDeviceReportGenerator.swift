// OnDeviceReportGenerator.swift
// Pepinillo — Deep Work Companion for Apple
//
// Generates AI-powered productivity reports using Apple Foundation Models
// (on-device, iOS 26+). Falls back gracefully when unavailable.
// Future improvement: Use @Generable for structured output once API is stable.

import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

struct OnDeviceReportGenerator: Sendable {

    // MARK: - Availability

    func isAvailable() -> Bool {
        #if canImport(FoundationModels)
        if #available(iOS 26, *) {
            let model = SystemLanguageModel.default
            switch model.availability {
            case .available:
                return true
            default:
                return false
            }
        }
        #endif
        return false
    }

    // MARK: - Generate

    func generate(from payload: ReportPayload) async -> AIReportResponse? {
        #if canImport(FoundationModels)
        if #available(iOS 26, *) {
            guard isAvailable() else { return nil }
            return await generateWithFoundationModels(payload: payload)
        }
        #endif
        return nil
    }

    // MARK: - Foundation Models Implementation

    #if canImport(FoundationModels)
    @available(iOS 26, *)
    private func generateWithFoundationModels(payload: ReportPayload) async -> AIReportResponse? {
        do {
            let session = LanguageModelSession()
            let prompt = buildPrompt(from: payload)
            let response = try await session.respond(to: prompt)
            return parseResponse(response.content)
        } catch {
            return nil
        }
    }
    #endif

    // MARK: - Prompt

    func buildPrompt(from payload: ReportPayload) -> String {
        let s = payload.summary
        let t = payload.trends
        let p = payload.patterns

        var topTasks = ""
        for (index, task) in payload.taskBreakdown.prefix(3).enumerated() {
            if index > 0 { topTasks += ", " }
            topTasks += "\(task.title) (\(task.focusMinutes)m)"
        }

        return """
        You are a productivity coach analyzing focus session data. Generate a brief, encouraging report.

        DATA:
        - Period: \(payload.period)
        - Total focus: \(s.totalFocusMinutes) min, \(s.sessions) sessions (\(s.completedSessions) completed)
        - Completion rate: \(Int(s.completionRate * 100))%
        - Focus time vs last period: \(t.focusMinutesDelta > 0 ? "+" : "")\(t.focusMinutesDelta) min
        - Peak hours: \(p.peakHours), Best day: \(p.bestDay)
        - Dominant mode: \(p.dominantMode)
        - Total interruptions: \(s.interruptions)
        - Top tasks: \(topTasks.isEmpty ? "none" : topTasks)

        Respond ONLY with a JSON object (no markdown, no code blocks) in this exact format:
        {
          "title": "Short encouraging title",
          "highlights": ["highlight 1", "highlight 2", "highlight 3"],
          "insights": [
            {"category": "pattern", "text": "insight about patterns"},
            {"category": "achievement", "text": "what they did well"},
            {"category": "improvement", "text": "area to improve"}
          ],
          "recommendations": ["recommendation 1", "recommendation 2"]
        }
        """
    }

    // MARK: - Response Parsing

    func parseResponse(_ text: String) -> AIReportResponse? {
        // Strategy 1: Direct JSON decode
        if let data = text.data(using: .utf8),
           let response = try? JSONDecoder().decode(AIReportResponse.self, from: data) {
            return response
        }

        // Strategy 2: Extract JSON from markdown code blocks
        let extracted = extractJSON(from: text)
        if let data = extracted.data(using: .utf8),
           let response = try? JSONDecoder().decode(AIReportResponse.self, from: data) {
            return response
        }

        return nil
    }

    private func extractJSON(from text: String) -> String {
        // Try ```json ... ``` blocks
        if let jsonRange = text.range(of: "```json"),
           let endRange = text.range(of: "```", range: jsonRange.upperBound..<text.endIndex) {
            return String(text[jsonRange.upperBound..<endRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // Try ``` ... ``` blocks
        if let startRange = text.range(of: "```"),
           let endRange = text.range(of: "```", range: startRange.upperBound..<text.endIndex) {
            return String(text[startRange.upperBound..<endRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // Try finding { ... } directly
        if let openBrace = text.firstIndex(of: "{"),
           let closeBrace = text.lastIndex(of: "}") {
            return String(text[openBrace...closeBrace])
        }

        return text
    }
}
