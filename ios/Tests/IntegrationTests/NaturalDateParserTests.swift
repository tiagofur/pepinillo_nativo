// NaturalDateParserTests.swift
// Pepinillo — Deep Work Companion for Apple
//
// Issue #994 (S1/S2): the natural-language planned-date grammar asserted
// against the shared case table versioned in the repo
// (contracts/fixtures/natural-date-cases-994.json) — the same file the web
// and Android suites decode. fixedNow is built in the LOCAL timezone of the
// test runner, from the components in the fixture (2026-11-27 is a Friday).

import Foundation
import Testing

@testable import Pepinillo

@Suite("NaturalDateParser")
struct NaturalDateParserTests {

    private struct FixedNowDTO: Decodable {
        let year: Int
        let month: Int
        let day: Int
        let hour: Int
        let minute: Int
    }

    /// Symbolic string ("today" | "tomorrow" | "dayAfterTomorrow") or object
    /// ({kind: "nextWeekday"|"explicit", weekday/year/month/day}).
    private enum ExpectedDateDTO: Decodable {
        case symbolic(String)
        case nextWeekday(weekday: Int)
        case explicit(year: Int, month: Int, day: Int)

        init(from decoder: Decoder) throws {
            if let single = try? decoder.singleValueContainer().decode(String.self) {
                self = .symbolic(single)
                return
            }
            let keyed = try decoder.container(keyedBy: CodingKeys.self)
            switch try keyed.decode(String.self, forKey: .kind) {
            case "nextWeekday":
                self = .nextWeekday(weekday: try keyed.decode(Int.self, forKey: .weekday))
            case "explicit":
                self = .explicit(
                    year: try keyed.decode(Int.self, forKey: .year),
                    month: try keyed.decode(Int.self, forKey: .month),
                    day: try keyed.decode(Int.self, forKey: .day)
                )
            case let other:
                throw DecodingError.dataCorruptedError(
                    forKey: .kind, in: keyed, debugDescription: "unknown kind \(other)")
            }
        }

        private enum CodingKeys: String, CodingKey {
            case kind, weekday, year, month, day
        }
    }

    private struct CaseDTO: Decodable {
        let name: String
        let input: String
        let expectedTitle: String
        let expectedDate: ExpectedDateDTO?
    }

    private struct FixtureDTO: Decodable {
        let fixedNow: FixedNowDTO
        let cases: [CaseDTO]
    }

    private func loadFixture() throws -> FixtureDTO {
        // ios/Tests/IntegrationTests/<file> → repo root is three levels up.
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let fixtureURL = repoRoot
            .appendingPathComponent("contracts")
            .appendingPathComponent("fixtures")
            .appendingPathComponent("natural-date-cases-994.json")
        let data = try Data(contentsOf: fixtureURL)
        return try JSONDecoder().decode(FixtureDTO.self, from: data)
    }

    private func localNoon(_ components: FixedNowDTO, calendar: Calendar) -> Date {
        var comps = DateComponents()
        comps.year = components.year
        comps.month = components.month
        comps.day = components.day
        comps.hour = components.hour
        comps.minute = components.minute
        return calendar.date(from: comps)!
    }

    /// Resolve the fixture's symbolic expectation against the shared fixedNow.
    private func expectedDay(
        _ expected: ExpectedDateDTO?, now: Date, calendar: Calendar
    ) -> Date? {
        guard let expected else { return nil }
        let day = calendar.startOfDay(for: now)
        switch expected {
        case .symbolic("today"):
            return day
        case .symbolic("tomorrow"):
            return calendar.date(byAdding: .day, value: 1, to: day)
        case .symbolic("dayAfterTomorrow"):
            return calendar.date(byAdding: .day, value: 2, to: day)
        case .nextWeekday(let weekday):
            let raw = calendar.component(.weekday, from: day)  // 1 = Sunday … 7 = Saturday
            let isoToday = raw == 1 ? 7 : raw - 1
            var delta = (weekday - isoToday + 7) % 7
            if delta == 0 { delta = 7 }
            return calendar.date(byAdding: .day, value: delta, to: day)
        case .explicit(let year, let month, let day):
            var comps = DateComponents()
            comps.year = year
            comps.month = month
            comps.day = day
            comps.hour = 12
            return calendar.date(from: comps)
        case .symbolic(let other):
            fatalError("unknown symbolic kind in fixture: \(other)")
        }
    }

    @Test func grammarMatchesTheSharedCaseTable() throws {
        let fixture = try loadFixture()
        #expect(fixture.cases.count >= 44, "the shared table keeps the whole grammar covered")
        let calendar = Calendar(identifier: .gregorian)
        let now = localNoon(fixture.fixedNow, calendar: calendar)

        for testCase in fixture.cases {
            let result = NaturalDateParser.parse(testCase.input, now: now, calendar: calendar)
            #expect(
                result.title == testCase.expectedTitle,
                "title — \(testCase.name): '\(result.title)' != '\(testCase.expectedTitle)'"
            )
            let expected = expectedDay(testCase.expectedDate, now: now, calendar: calendar)
            #expect(
                result.plannedDate == (expected.map { TaskPlanning.plannedDay($0, calendar: calendar) }),
                "plannedDate — \(testCase.name)"
            )
        }
    }

    @Test func captureWithoutTrailingDateIsByteIdentical() {
        let calendar = Calendar(identifier: .gregorian)
        let result = NaturalDateParser.parse(
            "  Reunión lunes de estrategia  ",
            now: Date(),
            calendar: calendar
        )
        #expect(result.plannedDate == nil)
        #expect(result.title == "Reunión lunes de estrategia")
    }

    @Test func plannedDateResolvesToStartOfLocalDay() throws {
        let fixture = try loadFixture()
        let calendar = Calendar(identifier: .gregorian)
        let now = localNoon(fixture.fixedNow, calendar: calendar)
        let result = NaturalDateParser.parse(
            "Enviar informe el viernes", now: now, calendar: calendar
        )
        let fridayNextWeek = expectedDay(
            .nextWeekday(weekday: 5), now: now, calendar: calendar
        )
        #expect(result.plannedDate == fridayNextWeek.map { calendar.startOfDay(for: $0) })
    }
}
