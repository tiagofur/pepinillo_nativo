// FocusGapsTests.swift
// Pepinillo — Deep Work Companion for Apple
//
// Issue #992 (S2): the «Huecos de hoy» engine asserted against the shared
// case table contracts/fixtures/focus-gaps-cases-992.json.

import Foundation
import Testing

@testable import Pepinillo

@Suite("FocusGaps")
struct FocusGapsTests {

    private struct EventDTO: Decodable {
        let startMin: Int
        let endMin: Int
        let isAllDay: Bool?
    }

    private struct GapDTO: Decodable {
        let startMin: Int
        let endMin: Int
    }

    private struct CaseDTO: Decodable {
        let name: String
        let events: [EventDTO]
        let expectedGaps: [GapDTO]
    }

    private struct FixtureDTO: Decodable {
        let fixedNow: FixedNowDTO
        let minimumGapMinutes: Int
        let maxShown: Int
        let cases: [CaseDTO]
    }

    private struct FixedNowDTO: Decodable {
        let year: Int
        let month: Int
        let day: Int
        let hour: Int
        let minute: Int
    }

    private func loadFixture() throws -> FixtureDTO {
        // ios/Tests/IntegrationTests/<file> → repo root is four levels up.
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let url = repoRoot
            .appendingPathComponent("contracts")
            .appendingPathComponent("fixtures")
            .appendingPathComponent("focus-gaps-cases-992.json")
        return try JSONDecoder().decode(FixtureDTO.self, from: Data(contentsOf: url))
    }

    @Test func gapsMatchTheSharedCaseTable() throws {
        let fixture = try loadFixture()
        #expect(fixture.cases.count >= 12, "the shared table covers the whole rule")

        let calendar = Calendar(identifier: .gregorian)
        var comps = DateComponents()
        comps.year = fixture.fixedNow.year
        comps.month = fixture.fixedNow.month
        comps.day = fixture.fixedNow.day
        comps.hour = fixture.fixedNow.hour
        comps.minute = fixture.fixedNow.minute
        let now = calendar.date(from: comps)!
        let dayStart = calendar.startOfDay(for: now)

        func at(_ minute: Int) -> Date {
            dayStart.addingTimeInterval(TimeInterval(minute) * 60)
        }

        for testCase in fixture.cases {
            let events = testCase.events.map {
                DayEvent(start: at($0.startMin), end: at($0.endMin), isAllDay: $0.isAllDay ?? false)
            }
            let gaps = FocusGaps.computeGaps(
                events: events,
                now: now,
                calendar: calendar,
                minimumGapMinutes: fixture.minimumGapMinutes,
                maxShown: fixture.maxShown
            )
            let expected = testCase.expectedGaps.map {
                FocusGap(start: at($0.startMin), end: at($0.endMin))
            }
            #expect(
                gaps == expected,
                "gaps — \(testCase.name): got \(gaps.map { "\($0.start)..\($0.end)" }) want \(expected.map { "\($0.start)..\($0.end)" })"
            )
        }
    }

    @Test func gapDurationFloorsWholeMinutes() {
        let start = Date(timeIntervalSince1970: 1_000)
        let gap = FocusGap(start: start, end: start.addingTimeInterval(24 * 60 + 59))
        #expect(gap.durationMinutes == 24)
    }
}
