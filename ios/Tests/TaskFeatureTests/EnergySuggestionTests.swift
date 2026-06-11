// EnergySuggestionTests.swift
// Pepinillo — Deep Work Companion for Apple
//
// Tests for EnergySuggestion hour → EnergyLevel mapping.
// All tests are pure (no I/O) and run synchronously.

import Testing
import Foundation
@testable import Pepinillo

struct EnergySuggestionTests {

    // MARK: - Boundary tests for each window

    @Test func hour06returnsDeep() {
        #expect(EnergySuggestion.suggestedLevel(forHour: 6) == .deep)
    }

    @Test func hour10returnsDeep() {
        #expect(EnergySuggestion.suggestedLevel(forHour: 10) == .deep)
    }

    @Test func hour11returnsShallow() {
        #expect(EnergySuggestion.suggestedLevel(forHour: 11) == .shallow)
    }

    @Test func hour12returnsShallow() {
        #expect(EnergySuggestion.suggestedLevel(forHour: 12) == .shallow)
    }

    @Test func hour13returnsAdmin() {
        #expect(EnergySuggestion.suggestedLevel(forHour: 13) == .admin)
    }

    @Test func hour14returnsAdmin() {
        #expect(EnergySuggestion.suggestedLevel(forHour: 14) == .admin)
    }

    @Test func hour15returnsDeep() {
        #expect(EnergySuggestion.suggestedLevel(forHour: 15) == .deep)
    }

    @Test func hour17returnsDeep() {
        #expect(EnergySuggestion.suggestedLevel(forHour: 17) == .deep)
    }

    @Test func hour18returnsShallow() {
        #expect(EnergySuggestion.suggestedLevel(forHour: 18) == .shallow)
    }

    @Test func hour20returnsShallow() {
        #expect(EnergySuggestion.suggestedLevel(forHour: 20) == .shallow)
    }

    @Test func hour21returnsAdmin() {
        #expect(EnergySuggestion.suggestedLevel(forHour: 21) == .admin)
    }

    @Test func hour23returnsAdmin() {
        #expect(EnergySuggestion.suggestedLevel(forHour: 23) == .admin)
    }

    @Test func hour00returnsAdmin() {
        #expect(EnergySuggestion.suggestedLevel(forHour: 0) == .admin)
    }

    @Test func hour05returnsAdmin() {
        #expect(EnergySuggestion.suggestedLevel(forHour: 5) == .admin)
    }

    // MARK: - All 24 hours are handled (no crash)

    @Test func allHoursReturnValidLevel() {
        for hour in 0..<24 {
            let level = EnergySuggestion.suggestedLevel(forHour: hour)
            #expect(EnergyLevel.allCases.contains(level), "Hour \(hour) returned unexpected level")
        }
    }

    // MARK: - Date-based entry point

    @Test func dateBasedOverloadMatchesHourBased() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!

        // Build a date at 9 AM New York time
        var components = DateComponents()
        components.year = 2025
        components.month = 6
        components.day = 10
        components.hour = 9
        components.minute = 0
        components.timeZone = TimeZone(identifier: "America/New_York")
        let date = calendar.date(from: components)!

        let level = EnergySuggestion.suggestedLevel(for: date, calendar: calendar)
        #expect(level == .deep)
    }
}
